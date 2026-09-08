#!/usr/bin/env python3
"""Compile the candidate's host expressions; device selection remains separate."""
from pathlib import Path
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
patch = (root / 'patches/llama-vulkan-q8-four-row-select.patch').read_text()
added = [line[1:] for line in patch.splitlines() if line.startswith('+') and not line.startswith('+++')]
removed = [line[1:] for line in patch.splitlines() if line.startswith('-') and not line.startswith('---')]
assert len(added) == 2 and len(removed) == 1
assert '"mul_mat_vec_q8_0_f32_f32"' in removed[0]
selection = next(line for line in added if 'const uint32_t q8_rows' in line)
pipeline = next(line for line in added if 'ggml_vk_create_pipeline(' in line)
geometry = re.search(r'sizeof\(vk_mat_vec_push_constants\), (\{[^}]+\}), (\{[^}]+\})', pipeline)
assert geometry is not None
denominator, specialization = geometry.groups()
program = '''#include <array>
#include <cassert>
#include <cstdint>
constexpr uint32_t VK_VENDOR_ID_AMD = 0x1002;
constexpr uint32_t AMD_GCN = 1;
struct Device { uint32_t vendor_id; uint32_t architecture; };
int main() {
 for (uint32_t vendor : {VK_VENDOR_ID_AMD, 0x10deu, 0x8086u}) {
  for (uint32_t architecture : {AMD_GCN, 2u}) {
   for (uint32_t rm_stdq : {1u, 2u}) {
    Device value{vendor, architecture};
    auto device = &value;
    const uint32_t expected = vendor == VK_VENDOR_ID_AMD && architecture == AMD_GCN ? 4u : rm_stdq;
'''
program += selection + '\n'
program += '''    for (uint32_t i = 0; i < 8; ++i) {
     const uint32_t wg_size_subgroup = 64;
'''
program += '     const std::array<uint32_t,3> denominator = ' + denominator + ';\n'
program += '     const std::array<uint32_t,3> specialization = ' + specialization + ';\n'
program += '''     assert(denominator[0] == expected);
     assert(specialization[1] == denominator[0]);
     assert(specialization[0] == 64 && specialization[2] == i + 1);
     assert(denominator[1] == 1 && denominator[2] == 1);
     if (expected == 4) assert((248320 + expected - 1) / expected == 62080);
    }
   }
  }
 }
}
'''
with tempfile.TemporaryDirectory(prefix='q8-host-selection-') as directory:
    source = Path(directory) / 'selection.cpp'
    binary = Path(directory) / 'selection'
    source.write_text(program)
    subprocess.run(['c++', '-std=c++17', '-Wall', '-Wextra', '-Werror', str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
print('q8_host_expression_fixture=accepted device_execution=unmeasured')
