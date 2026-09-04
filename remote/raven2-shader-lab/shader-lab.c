/* Create one Vulkan compute pipeline from a .spv file and exit, so RADV
 * compiles SPIR-V to gfx902 ISA inside vkCreateComputePipelines and its
 * RADV_DEBUG dumps reach stderr. mesa-25.3.2
 * src/amd/vulkan/radv_pipeline_compute.c prints the final NIR, the ACO
 * backend IR, and the disassembly from that one call under the instance's
 * shader_dump_mtx, and src/amd/vulkan/radv_shader.c:3282 writes the
 * "disasm:" block, so a pipeline creation is the whole measurement and no
 * dispatch is issued.
 *
 * The pipeline is reconstructed to match what llama.cpp asks RADV for rather
 * than to the minimum a .spv will load under. ggml_vk_create_pipeline in
 * ggml/src/ggml-vulkan/ggml-vulkan.cpp passes a descriptor set of N storage
 * buffers, a push-constant range, a specialization constant array, and a
 * required subgroup size with full subgroups; a layout that under-declares
 * what the shader indexes changes RADV's descriptor lowering, and a missing
 * device feature changes instruction selection, so both are stated on the
 * command line and both are checked against the SPIR-V's own OpCapability
 * list before the device is created.
 *
 * The mat-vec family's constants are ids 0, 1, and 2, declared in
 * ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vec_base.glsl as BLOCK_SIZE,
 * NUM_ROWS, and NUM_COLS, with mul_mat_vec_q4_k.comp's
 * local_size_x_id = 0 aliasing the first.
 *
 * usage: shader-lab SHADER.spv [--spec ID:UINT]... [--subgroup N]
 *                   [--bindings N] [--push-constants BYTES]
 *                   [--device-index N]
 * Builds with: cc -O2 -Wall -Wextra shader-lab.c -lvulkan
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <vulkan/vulkan.h>

#define MAX_SPEC_CONSTANTS 32
#define MAX_CAPABILITIES 128
#define MAX_ENABLED_FEATURES 32

/* SPIR-V 1.6 unified capability numbers, from the SPIR-V specification's
 * Capability table. Only the capabilities that select a Vulkan device
 * feature, plus the ones every compute module declares, are named; an
 * unnamed capability is reported by number and enables nothing. */
struct capability_name {
    uint32_t value;
    const char *name;
};

static const struct capability_name CAPABILITY_NAMES[] = {
    {0, "Matrix"},
    {1, "Shader"},
    {9, "Float16"},
    {10, "Float64"},
    {11, "Int64"},
    {22, "Int16"},
    {39, "Int8"},
    {61, "GroupNonUniform"},
    {62, "GroupNonUniformVote"},
    {63, "GroupNonUniformArithmetic"},
    {64, "GroupNonUniformBallot"},
    {65, "GroupNonUniformShuffle"},
    {66, "GroupNonUniformShuffleRelative"},
    {67, "GroupNonUniformClustered"},
    {68, "GroupNonUniformQuad"},
    {4427, "DrawParameters"},
    {4433, "StorageBuffer16BitAccess"},
    {4434, "UniformAndStorageBuffer16BitAccess"},
    {4435, "StoragePushConstant16"},
    {4437, "DeviceGroup"},
    {4445, "ShaderNonUniform"},
    {4447, "RuntimeDescriptorArray"},
    {4448, "StorageBuffer8BitAccess"},
    {4449, "UniformAndStorageBuffer8BitAccess"},
    {4450, "StoragePushConstant8"},
    {5345, "VulkanMemoryModel"},
    {5346, "VulkanMemoryModelDeviceScope"},
    {5347, "PhysicalStorageBufferAddresses"},
    {6016, "DotProduct"},
    {6017, "DotProductInputAll"},
    {6018, "DotProductInput4x8Bit"},
    {6019, "DotProductInput4x8BitPacked"},
};

struct spec_constant {
    uint32_t id;
    uint32_t value;
};

struct lab_options {
    const char *spirv_path;
    struct spec_constant spec_constants[MAX_SPEC_CONSTANTS];
    uint32_t spec_constant_count;
    uint32_t required_subgroup_size;
    uint32_t binding_count;
    uint32_t push_constant_bytes;
    uint32_t device_index;
};

static void print_usage(const char *program_name) {
    fprintf(stderr,
            "usage: %s SHADER.spv [--spec ID:UINT]... [--subgroup N]\n"
            "                     [--bindings N] [--push-constants BYTES]\n"
            "                     [--device-index N]\n",
            program_name);
}

static const char *capability_name(uint32_t value) {
    for (size_t i = 0; i < sizeof(CAPABILITY_NAMES) / sizeof(CAPABILITY_NAMES[0]); ++i) {
        if (CAPABILITY_NAMES[i].value == value) {
            return CAPABILITY_NAMES[i].name;
        }
    }
    return NULL;
}

static int parse_unsigned(const char *text, uint32_t *out_value) {
    char *end = NULL;
    unsigned long parsed = strtoul(text, &end, 10);
    if (end == text || *end != '\0' || parsed > 0xFFFFFFFFul) {
        return 0;
    }
    *out_value = (uint32_t)parsed;
    return 1;
}

static int parse_options(int argc, char **argv, struct lab_options *options) {
    options->spirv_path = NULL;
    options->spec_constant_count = 0;
    options->required_subgroup_size = 0;
    options->binding_count = 3;
    options->push_constant_bytes = 0;
    options->device_index = 0;

    for (int i = 1; i < argc; ++i) {
        const char *argument = argv[i];
        if (strcmp(argument, "--spec") == 0) {
            if (++i >= argc) {
                fprintf(stderr, "--spec takes ID:UINT\n");
                return 0;
            }
            const char *separator = strchr(argv[i], ':');
            if (!separator) {
                fprintf(stderr, "--spec takes ID:UINT, read %s\n", argv[i]);
                return 0;
            }
            char id_text[32];
            size_t id_length = (size_t)(separator - argv[i]);
            if (id_length == 0 || id_length >= sizeof(id_text)) {
                fprintf(stderr, "--spec id is empty or too long: %s\n", argv[i]);
                return 0;
            }
            memcpy(id_text, argv[i], id_length);
            id_text[id_length] = '\0';
            if (options->spec_constant_count >= MAX_SPEC_CONSTANTS) {
                fprintf(stderr, "at most %d specialization constants are accepted\n", MAX_SPEC_CONSTANTS);
                return 0;
            }
            struct spec_constant *constant = &options->spec_constants[options->spec_constant_count];
            if (!parse_unsigned(id_text, &constant->id) || !parse_unsigned(separator + 1, &constant->value)) {
                fprintf(stderr, "--spec ID and UINT are decimal unsigned integers: %s\n", argv[i]);
                return 0;
            }
            options->spec_constant_count++;
            continue;
        }
        if (strcmp(argument, "--subgroup") == 0) {
            if (++i >= argc || !parse_unsigned(argv[i], &options->required_subgroup_size)) {
                fprintf(stderr, "--subgroup takes a decimal wave size\n");
                return 0;
            }
            continue;
        }
        if (strcmp(argument, "--bindings") == 0) {
            if (++i >= argc || !parse_unsigned(argv[i], &options->binding_count) ||
                options->binding_count == 0) {
                fprintf(stderr, "--bindings takes a positive storage-buffer count\n");
                return 0;
            }
            continue;
        }
        if (strcmp(argument, "--push-constants") == 0) {
            if (++i >= argc || !parse_unsigned(argv[i], &options->push_constant_bytes)) {
                fprintf(stderr, "--push-constants takes a byte count\n");
                return 0;
            }
            continue;
        }
        if (strcmp(argument, "--device-index") == 0) {
            if (++i >= argc || !parse_unsigned(argv[i], &options->device_index)) {
                fprintf(stderr, "--device-index takes a physical device index\n");
                return 0;
            }
            continue;
        }
        if (argument[0] == '-') {
            fprintf(stderr, "unknown option: %s\n", argument);
            return 0;
        }
        if (options->spirv_path) {
            fprintf(stderr, "exactly one SHADER.spv is accepted\n");
            return 0;
        }
        options->spirv_path = argument;
    }
    if (!options->spirv_path) {
        fprintf(stderr, "a SHADER.spv path is required\n");
        return 0;
    }
    if (options->push_constant_bytes % 4 != 0) {
        fprintf(stderr, "--push-constants is a multiple of 4: %u\n", options->push_constant_bytes);
        return 0;
    }
    return 1;
}

static uint32_t *read_spirv(const char *path, size_t *out_byte_count) {
    FILE *spirv_file = fopen(path, "rb");
    if (!spirv_file) {
        perror(path);
        return NULL;
    }
    if (fseek(spirv_file, 0, SEEK_END) != 0) {
        perror(path);
        fclose(spirv_file);
        return NULL;
    }
    long byte_count = ftell(spirv_file);
    rewind(spirv_file);
    if (byte_count <= 20 || byte_count % 4 != 0) {
        fprintf(stderr, "%s: %ld bytes is not a SPIR-V module\n", path, byte_count);
        fclose(spirv_file);
        return NULL;
    }
    uint32_t *code = malloc((size_t)byte_count);
    if (!code) {
        fprintf(stderr, "%s: allocation of %ld bytes failed\n", path, byte_count);
        fclose(spirv_file);
        return NULL;
    }
    if (fread(code, 1, (size_t)byte_count, spirv_file) != (size_t)byte_count) {
        fprintf(stderr, "%s: short read\n", path);
        free(code);
        fclose(spirv_file);
        return NULL;
    }
    fclose(spirv_file);
    if (code[0] != 0x07230203u) {
        fprintf(stderr, "%s: magic word %08x is not SPIR-V\n", path, code[0]);
        free(code);
        return NULL;
    }
    *out_byte_count = (size_t)byte_count;
    return code;
}

/* Collect the module's OpCapability operands. A SPIR-V module opens with a
 * five-word header and OpCapability, opcode 17, is a two-word instruction
 * whose single operand is the capability number; the capability block
 * precedes every other section, so a walk that stops at the first
 * non-capability instruction after the block has read them all. The walk
 * here reads the whole module instead, which costs nothing and survives a
 * module the assembler ordered differently. */
static uint32_t collect_capabilities(const uint32_t *code, size_t byte_count, uint32_t *capabilities) {
    size_t word_count = byte_count / 4;
    size_t index = 5;
    uint32_t found = 0;
    while (index < word_count) {
        uint32_t opcode = code[index] & 0xFFFFu;
        uint32_t instruction_words = code[index] >> 16;
        if (instruction_words == 0 || index + instruction_words > word_count) {
            break;
        }
        if (opcode == 17 && instruction_words >= 2 && found < MAX_CAPABILITIES) {
            capabilities[found++] = code[index + 1];
        }
        index += instruction_words;
    }
    return found;
}

struct device_feature_request {
    VkPhysicalDeviceFeatures2 features2;
    VkPhysicalDeviceVulkan11Features vulkan11;
    VkPhysicalDeviceVulkan12Features vulkan12;
    VkPhysicalDeviceVulkan13Features vulkan13;
};

static void init_feature_request(struct device_feature_request *request) {
    memset(request, 0, sizeof(*request));
    request->features2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2;
    request->features2.pNext = &request->vulkan11;
    request->vulkan11.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES;
    request->vulkan11.pNext = &request->vulkan12;
    request->vulkan12.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES;
    request->vulkan12.pNext = &request->vulkan13;
    request->vulkan13.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES;
    request->vulkan13.pNext = NULL;
}

/* One SPIR-V capability maps to at most one Vulkan feature bit. The offsets
 * name the bit inside whichever of the four feature structures carries it,
 * so one table drives both the support check against the device's reported
 * features and the enable in the device creation request. */
struct feature_binding {
    uint32_t capability;
    const char *feature_name;
    int structure; /* 0 core, 1 Vulkan11, 2 Vulkan12, 3 Vulkan13 */
    size_t offset;
};

static const struct feature_binding FEATURE_BINDINGS[] = {
    {9, "shaderFloat16", 2, offsetof(VkPhysicalDeviceVulkan12Features, shaderFloat16)},
    {10, "shaderFloat64", 0, offsetof(VkPhysicalDeviceFeatures, shaderFloat64)},
    {11, "shaderInt64", 0, offsetof(VkPhysicalDeviceFeatures, shaderInt64)},
    {22, "shaderInt16", 0, offsetof(VkPhysicalDeviceFeatures, shaderInt16)},
    {39, "shaderInt8", 2, offsetof(VkPhysicalDeviceVulkan12Features, shaderInt8)},
    {4433, "storageBuffer16BitAccess", 1, offsetof(VkPhysicalDeviceVulkan11Features, storageBuffer16BitAccess)},
    {4434, "uniformAndStorageBuffer16BitAccess", 1,
     offsetof(VkPhysicalDeviceVulkan11Features, uniformAndStorageBuffer16BitAccess)},
    {4435, "storagePushConstant16", 1, offsetof(VkPhysicalDeviceVulkan11Features, storagePushConstant16)},
    {4448, "storageBuffer8BitAccess", 2, offsetof(VkPhysicalDeviceVulkan12Features, storageBuffer8BitAccess)},
    {4449, "uniformAndStorageBuffer8BitAccess", 2,
     offsetof(VkPhysicalDeviceVulkan12Features, uniformAndStorageBuffer8BitAccess)},
    {4450, "storagePushConstant8", 2, offsetof(VkPhysicalDeviceVulkan12Features, storagePushConstant8)},
    {5345, "vulkanMemoryModel", 2, offsetof(VkPhysicalDeviceVulkan12Features, vulkanMemoryModel)},
    {5346, "vulkanMemoryModelDeviceScope", 2,
     offsetof(VkPhysicalDeviceVulkan12Features, vulkanMemoryModelDeviceScope)},
    {5347, "bufferDeviceAddress", 2, offsetof(VkPhysicalDeviceVulkan12Features, bufferDeviceAddress)},
    {6016, "shaderIntegerDotProduct", 3, offsetof(VkPhysicalDeviceVulkan13Features, shaderIntegerDotProduct)},
};

static VkBool32 *feature_slot(struct device_feature_request *request, const struct feature_binding *binding) {
    char *base = NULL;
    switch (binding->structure) {
    case 0:
        base = (char *)&request->features2.features;
        break;
    case 1:
        base = (char *)&request->vulkan11;
        break;
    case 2:
        base = (char *)&request->vulkan12;
        break;
    default:
        base = (char *)&request->vulkan13;
        break;
    }
    return (VkBool32 *)(void *)(base + binding->offset);
}

int main(int argc, char **argv) {
    struct lab_options options;
    if (!parse_options(argc, argv, &options)) {
        print_usage(argv[0]);
        return 2;
    }

    size_t spirv_byte_count = 0;
    uint32_t *spirv_code = read_spirv(options.spirv_path, &spirv_byte_count);
    if (!spirv_code) {
        return 1;
    }

    uint32_t capabilities[MAX_CAPABILITIES];
    uint32_t capability_count = collect_capabilities(spirv_code, spirv_byte_count, capabilities);

    VkApplicationInfo application_info = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "raven2-shader-lab",
        .apiVersion = VK_API_VERSION_1_3,
    };
    VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application_info,
    };
    VkInstance instance;
    VkResult result = vkCreateInstance(&instance_info, NULL, &instance);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateInstance failed: %d\n", (int)result);
        return 1;
    }

    uint32_t physical_device_count = 0;
    vkEnumeratePhysicalDevices(instance, &physical_device_count, NULL);
    if (physical_device_count <= options.device_index) {
        fprintf(stderr, "device index %u is beyond the %u reported physical devices\n", options.device_index,
                physical_device_count);
        return 1;
    }
    VkPhysicalDevice *physical_devices = malloc(sizeof(VkPhysicalDevice) * physical_device_count);
    if (!physical_devices) {
        fprintf(stderr, "allocation for %u physical devices failed\n", physical_device_count);
        return 1;
    }
    vkEnumeratePhysicalDevices(instance, &physical_device_count, physical_devices);
    VkPhysicalDevice physical_device = physical_devices[options.device_index];
    free(physical_devices);

    VkPhysicalDeviceSubgroupSizeControlProperties subgroup_size_properties = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES,
    };
    VkPhysicalDeviceProperties2 device_properties = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
        .pNext = &subgroup_size_properties,
    };
    vkGetPhysicalDeviceProperties2(physical_device, &device_properties);

    VkPhysicalDeviceDriverProperties driver_properties = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES,
    };
    VkPhysicalDeviceProperties2 driver_query = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,
        .pNext = &driver_properties,
    };
    vkGetPhysicalDeviceProperties2(physical_device, &driver_query);

    printf("device_name=%s\n", device_properties.properties.deviceName);
    printf("driver_name=%s\n", driver_properties.driverName);
    printf("driver_info=%s\n", driver_properties.driverInfo);
    printf("device_api_version=%u.%u.%u\n", VK_VERSION_MAJOR(device_properties.properties.apiVersion),
           VK_VERSION_MINOR(device_properties.properties.apiVersion),
           VK_VERSION_PATCH(device_properties.properties.apiVersion));
    printf("subgroup_size_min=%u\n", subgroup_size_properties.minSubgroupSize);
    printf("subgroup_size_max=%u\n", subgroup_size_properties.maxSubgroupSize);
    printf("spirv_bytes=%zu\n", spirv_byte_count);

    struct device_feature_request supported;
    init_feature_request(&supported);
    VkPhysicalDeviceSubgroupSizeControlFeatures supported_subgroup_control = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES,
    };
    supported.vulkan13.pNext = &supported_subgroup_control;
    vkGetPhysicalDeviceFeatures2(physical_device, &supported.features2);

    struct device_feature_request requested;
    init_feature_request(&requested);
    VkPhysicalDeviceSubgroupSizeControlFeatures requested_subgroup_control = {
        .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES,
    };
    requested.vulkan13.pNext = &requested_subgroup_control;

    /* Every capability the module declares either names a feature this
     * device reports, and the feature is enabled, or the run ends naming the
     * capability. A pipeline created without a capability's feature compiles
     * to a different instruction sequence or fails inside the driver, and
     * either outcome would be read as a property of the shader. */
    char capability_list[1024];
    size_t capability_list_length = 0;
    const char *enabled_features[MAX_ENABLED_FEATURES];
    uint32_t enabled_feature_count = 0;
    int capability_refused = 0;
    for (uint32_t i = 0; i < capability_count; ++i) {
        uint32_t capability = capabilities[i];
        const char *name = capability_name(capability);
        char rendered[64];
        if (name) {
            snprintf(rendered, sizeof(rendered), "%s", name);
        } else {
            snprintf(rendered, sizeof(rendered), "capability_%u", capability);
        }
        int written = snprintf(capability_list + capability_list_length,
                               sizeof(capability_list) - capability_list_length, "%s%s",
                               capability_list_length ? "," : "", rendered);
        if (written > 0 && (size_t)written < sizeof(capability_list) - capability_list_length) {
            capability_list_length += (size_t)written;
        }
        for (size_t b = 0; b < sizeof(FEATURE_BINDINGS) / sizeof(FEATURE_BINDINGS[0]); ++b) {
            const struct feature_binding *binding = &FEATURE_BINDINGS[b];
            if (binding->capability != capability) {
                continue;
            }
            if (*feature_slot(&supported, binding) != VK_TRUE) {
                fprintf(stderr, "%s declares %s and this device reports %s unsupported\n", options.spirv_path,
                        rendered, binding->feature_name);
                capability_refused = 1;
                break;
            }
            *feature_slot(&requested, binding) = VK_TRUE;
            if (enabled_feature_count < MAX_ENABLED_FEATURES) {
                enabled_features[enabled_feature_count++] = binding->feature_name;
            }
            break;
        }
    }
    printf("spirv_capabilities=%s\n", capability_list_length ? capability_list : "-");
    if (capability_refused) {
        return 1;
    }

    /* ggml passes require_full_subgroups beside its required subgroup size,
     * so both feature bits are enabled where a wave size is asked for; the
     * gfx9 compute default is already wave64, which is what makes a silently
     * ignored pNext look correct on this part and wrong on a wave32 one. */
    if (options.required_subgroup_size > 0) {
        if (supported_subgroup_control.subgroupSizeControl != VK_TRUE ||
            supported_subgroup_control.computeFullSubgroups != VK_TRUE) {
            fprintf(stderr, "--subgroup %u needs subgroupSizeControl and computeFullSubgroups, which this device "
                            "reports unsupported\n",
                    options.required_subgroup_size);
            return 1;
        }
        if (options.required_subgroup_size < subgroup_size_properties.minSubgroupSize ||
            options.required_subgroup_size > subgroup_size_properties.maxSubgroupSize) {
            fprintf(stderr, "--subgroup %u is outside the device range %u to %u\n", options.required_subgroup_size,
                    subgroup_size_properties.minSubgroupSize, subgroup_size_properties.maxSubgroupSize);
            return 1;
        }
        requested_subgroup_control.subgroupSizeControl = VK_TRUE;
        requested_subgroup_control.computeFullSubgroups = VK_TRUE;
        if (enabled_feature_count + 2 <= MAX_ENABLED_FEATURES) {
            enabled_features[enabled_feature_count++] = "subgroupSizeControl";
            enabled_features[enabled_feature_count++] = "computeFullSubgroups";
        }
    }

    printf("features_enabled=");
    for (uint32_t i = 0; i < enabled_feature_count; ++i) {
        printf("%s%s", i ? "," : "", enabled_features[i]);
    }
    printf("%s\n", enabled_feature_count ? "" : "-");

    /* robustBufferAccess stays clear, matching ggml's disable_robustness for
     * the mat-vec pipelines: robustness on adds a bounds check per buffer
     * access and moves every instruction count this lab reports. */
    printf("robust_buffer_access=off\n");

    uint32_t queue_family_count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, NULL);
    VkQueueFamilyProperties *queue_families = malloc(sizeof(VkQueueFamilyProperties) * queue_family_count);
    if (!queue_families) {
        fprintf(stderr, "allocation for %u queue families failed\n", queue_family_count);
        return 1;
    }
    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families);
    uint32_t compute_family_index = UINT32_MAX;
    for (uint32_t i = 0; i < queue_family_count; ++i) {
        if (queue_families[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
            compute_family_index = i;
            break;
        }
    }
    free(queue_families);
    if (compute_family_index == UINT32_MAX) {
        fprintf(stderr, "this device reports no compute-capable queue family\n");
        return 1;
    }

    float queue_priority = 1.0f;
    VkDeviceQueueCreateInfo queue_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = compute_family_index,
        .queueCount = 1,
        .pQueuePriorities = &queue_priority,
    };
    VkDeviceCreateInfo device_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = &requested.features2,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
    };
    VkDevice device;
    result = vkCreateDevice(physical_device, &device_info, NULL, &device);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateDevice failed: %d\n", (int)result);
        return 1;
    }

    VkShaderModuleCreateInfo module_info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = spirv_byte_count,
        .pCode = spirv_code,
    };
    VkShaderModule shader_module;
    result = vkCreateShaderModule(device, &module_info, NULL, &shader_module);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateShaderModule failed: %d\n", (int)result);
        return 1;
    }

    VkDescriptorSetLayoutBinding *bindings = calloc(options.binding_count, sizeof(*bindings));
    if (!bindings) {
        fprintf(stderr, "allocation for %u descriptor bindings failed\n", options.binding_count);
        return 1;
    }
    for (uint32_t i = 0; i < options.binding_count; ++i) {
        bindings[i].binding = i;
        bindings[i].descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
        bindings[i].descriptorCount = 1;
        bindings[i].stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;
    }
    VkDescriptorSetLayoutCreateInfo set_layout_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = options.binding_count,
        .pBindings = bindings,
    };
    VkDescriptorSetLayout set_layout;
    result = vkCreateDescriptorSetLayout(device, &set_layout_info, NULL, &set_layout);
    free(bindings);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateDescriptorSetLayout failed: %d\n", (int)result);
        return 1;
    }

    VkPushConstantRange push_constant_range = {
        .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0,
        .size = options.push_constant_bytes,
    };
    VkPipelineLayoutCreateInfo pipeline_layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &set_layout,
        .pushConstantRangeCount = options.push_constant_bytes > 0 ? 1u : 0u,
        .pPushConstantRanges = options.push_constant_bytes > 0 ? &push_constant_range : NULL,
    };
    VkPipelineLayout pipeline_layout;
    result = vkCreatePipelineLayout(device, &pipeline_layout_info, NULL, &pipeline_layout);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreatePipelineLayout failed: %d\n", (int)result);
        return 1;
    }

    /* One four-byte entry per constant at its own offset, the shape
     * ggml_vk_create_pipeline_func builds from its specialization_constants
     * vector. */
    VkSpecializationMapEntry map_entries[MAX_SPEC_CONSTANTS];
    uint32_t specialization_values[MAX_SPEC_CONSTANTS];
    for (uint32_t i = 0; i < options.spec_constant_count; ++i) {
        map_entries[i].constantID = options.spec_constants[i].id;
        map_entries[i].offset = i * (uint32_t)sizeof(uint32_t);
        map_entries[i].size = sizeof(uint32_t);
        specialization_values[i] = options.spec_constants[i].value;
    }
    VkSpecializationInfo specialization_info = {
        .mapEntryCount = options.spec_constant_count,
        .pMapEntries = map_entries,
        .dataSize = options.spec_constant_count * sizeof(uint32_t),
        .pData = specialization_values,
    };

    VkPipelineShaderStageRequiredSubgroupSizeCreateInfo required_subgroup_size_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO,
        .requiredSubgroupSize = options.required_subgroup_size,
    };
    VkComputePipelineCreateInfo pipeline_info = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage =
            {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .pNext = options.required_subgroup_size > 0 ? &required_subgroup_size_info : NULL,
                .flags = options.required_subgroup_size > 0
                             ? VK_PIPELINE_SHADER_STAGE_CREATE_REQUIRE_FULL_SUBGROUPS_BIT
                             : 0u,
                .stage = VK_SHADER_STAGE_COMPUTE_BIT,
                .module = shader_module,
                .pName = "main",
                .pSpecializationInfo = options.spec_constant_count > 0 ? &specialization_info : NULL,
            },
        .layout = pipeline_layout,
    };

    printf("spec_constants=");
    for (uint32_t i = 0; i < options.spec_constant_count; ++i) {
        printf("%s%u:%u", i ? "," : "", options.spec_constants[i].id, options.spec_constants[i].value);
    }
    printf("%s\n", options.spec_constant_count ? "" : "-");
    printf("bindings=%u\n", options.binding_count);
    printf("push_constant_bytes=%u\n", options.push_constant_bytes);
    printf("subgroup_size_requested=%u\n", options.required_subgroup_size);
    fflush(stdout);

    VkPipeline pipeline;
    result = vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipeline_info, NULL, &pipeline);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateComputePipelines failed: %d\n", (int)result);
        return 1;
    }
    printf("pipeline_created=%s\n", options.spirv_path);

    vkDestroyPipeline(device, pipeline, NULL);
    vkDestroyPipelineLayout(device, pipeline_layout, NULL);
    vkDestroyDescriptorSetLayout(device, set_layout, NULL);
    vkDestroyShaderModule(device, shader_module, NULL);
    vkDestroyDevice(device, NULL);
    vkDestroyInstance(instance, NULL);
    free(spirv_code);
    return 0;
}
