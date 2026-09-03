/* Minimal harness for the E2 probe in
 * evidence/raven2-vulkan-kernel-census/decode-decomposition.md: create a
 * Vulkan instance and device, build a compute pipeline from one .spv file
 * named on the command line, and exit. RADV compiles SPIR-V to native ISA
 * inside vkCreateComputePipelines, so RADV_DEBUG=shaders,shaderstats prints
 * the disassembly and statistics from within that one call; nothing here
 * records or dispatches, and remote/isa-probes/README.md states how the
 * caller reads the result from stderr.
 *
 * usage: run-probe SHADER.spv
 * Builds with: cc run-probe.c -lvulkan
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <vulkan/vulkan.h>

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s SHADER.spv\n", argv[0]);
        return 2;
    }

    FILE *spirv_file = fopen(argv[1], "rb");
    if (!spirv_file) {
        perror(argv[1]);
        return 1;
    }
    fseek(spirv_file, 0, SEEK_END);
    long spirv_byte_count = ftell(spirv_file);
    fseek(spirv_file, 0, SEEK_SET);
    if (spirv_byte_count <= 0 || spirv_byte_count % 4 != 0) {
        fprintf(stderr, "%s: %ld bytes is not a nonempty multiple of 4\n", argv[1], spirv_byte_count);
        return 1;
    }
    uint32_t *spirv_code = malloc((size_t)spirv_byte_count);
    if (fread(spirv_code, 1, (size_t)spirv_byte_count, spirv_file) != (size_t)spirv_byte_count) {
        fprintf(stderr, "%s: short read\n", argv[1]);
        return 1;
    }
    fclose(spirv_file);

    VkApplicationInfo application_info = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "radv-isa-probe",
        .apiVersion = VK_API_VERSION_1_3,
    };
    VkInstanceCreateInfo instance_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &application_info,
    };
    VkInstance instance;
    if (vkCreateInstance(&instance_info, NULL, &instance) != VK_SUCCESS) {
        fprintf(stderr, "vkCreateInstance failed\n");
        return 1;
    }

    uint32_t physical_device_count = 0;
    vkEnumeratePhysicalDevices(instance, &physical_device_count, NULL);
    if (physical_device_count == 0) {
        fprintf(stderr, "no Vulkan physical device is reported\n");
        return 1;
    }
    VkPhysicalDevice *physical_devices = malloc(sizeof(VkPhysicalDevice) * physical_device_count);
    vkEnumeratePhysicalDevices(instance, &physical_device_count, physical_devices);
    VkPhysicalDevice physical_device = physical_devices[0];
    free(physical_devices);

    uint32_t queue_family_count = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, NULL);
    VkQueueFamilyProperties *queue_families = malloc(sizeof(VkQueueFamilyProperties) * queue_family_count);
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
        fprintf(stderr, "no compute-capable queue family is reported\n");
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
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &queue_info,
    };
    VkDevice device;
    if (vkCreateDevice(physical_device, &device_info, NULL, &device) != VK_SUCCESS) {
        fprintf(stderr, "vkCreateDevice failed\n");
        return 1;
    }

    VkShaderModuleCreateInfo module_info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = (size_t)spirv_byte_count,
        .pCode = spirv_code,
    };
    VkShaderModule shader_module;
    if (vkCreateShaderModule(device, &module_info, NULL, &shader_module) != VK_SUCCESS) {
        fprintf(stderr, "vkCreateShaderModule failed\n");
        return 1;
    }

    /* Three storage buffers at bindings 0, 1, and 2, matching the layout
     * every shader in this directory declares. */
    VkDescriptorSetLayoutBinding bindings[3];
    for (uint32_t i = 0; i < 3; ++i) {
        bindings[i] = (VkDescriptorSetLayoutBinding){
            .binding = i,
            .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .descriptorCount = 1,
            .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT,
        };
    }
    VkDescriptorSetLayoutCreateInfo set_layout_info = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 3,
        .pBindings = bindings,
    };
    VkDescriptorSetLayout set_layout;
    if (vkCreateDescriptorSetLayout(device, &set_layout_info, NULL, &set_layout) != VK_SUCCESS) {
        fprintf(stderr, "vkCreateDescriptorSetLayout failed\n");
        return 1;
    }

    VkPipelineLayoutCreateInfo pipeline_layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1,
        .pSetLayouts = &set_layout,
    };
    VkPipelineLayout pipeline_layout;
    if (vkCreatePipelineLayout(device, &pipeline_layout_info, NULL, &pipeline_layout) != VK_SUCCESS) {
        fprintf(stderr, "vkCreatePipelineLayout failed\n");
        return 1;
    }

    VkComputePipelineCreateInfo pipeline_info = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage =
            {
                .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
                .stage = VK_SHADER_STAGE_COMPUTE_BIT,
                .module = shader_module,
                .pName = "main",
            },
        .layout = pipeline_layout,
    };
    VkPipeline pipeline;
    VkResult result = vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipeline_info, NULL, &pipeline);
    if (result != VK_SUCCESS) {
        fprintf(stderr, "vkCreateComputePipelines failed: %d\n", (int)result);
        return 1;
    }
    fprintf(stderr, "pipeline created from %s\n", argv[1]);

    vkDestroyPipeline(device, pipeline, NULL);
    vkDestroyPipelineLayout(device, pipeline_layout, NULL);
    vkDestroyDescriptorSetLayout(device, set_layout, NULL);
    vkDestroyShaderModule(device, shader_module, NULL);
    vkDestroyDevice(device, NULL);
    vkDestroyInstance(instance, NULL);
    free(spirv_code);
    return 0;
}
