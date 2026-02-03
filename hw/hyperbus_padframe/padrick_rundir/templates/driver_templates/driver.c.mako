## Manuel Eggimann <meggimann@iis.ee.ethz.ch>
##
## Copyright (C) 2021-2022 ETH Zürich
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

<%
  import math
  from natsort import natsorted
%>
#include "${padframe.name}.h"
% for pad_domain in padframe.pad_domains:
#define  ${padframe.name.upper()}_${pad_domain.name.upper()}_CONFIG0_BASE_ADDR ${padframe.name.upper()}_BASE_ADDRESS
#include "${padframe.name}_${pad_domain.name}_regs.h"
#include "bitfield.h"
% endfor

#define REG_WRITE32(addr, value) *((volatile uint32_t*) addr) = (uint32_t) value;
#define REG_READ32(addr) *((volatile uint32_t*) addr)

% for pad_domain in padframe.pad_domains:
% for pad in pad_domain.pad_list:
% for ps in pad.dynamic_pad_signals_soc2pad:
<%
  # Determine appropriate type for field value
  if ps.size <= 8:
      field_type = "uint8_t"
  elif ps.size <= 16:
      field_type = "uint16_t"
  else:
      field_type = "uint32_t"
  address = f"{padframe.name.upper()}_{pad_domain.name.upper()}_CONFIG_{pad.name.upper()}_CFG_REG_OFFSET"
  all_ports_in_mux_group = pad_domain.get_ports_in_mux_groups(pad.mux_groups)
  sel_size = max(1,math.ceil(math.log2(len(all_ports_in_mux_group)+1)))
  field_name = f"{padframe.name.upper()}_{pad_domain.name.upper()}_CONFIG_{pad.name.upper()}_CFG_{ps.name.upper()}"
%>
void ${padframe.name}_${pad_domain.name}_${pad.name}_cfg_${ps.name}_set(${field_type} value) {
  uint32_t address = ${padframe.name.upper()}_BASE_ADDRESS + ${address};
  uint32_t reg = REG_READ32(address);
%if ps.size > 1:
  reg = bitfield_field32_write(reg, ${field_name}_FIELD, value);
%else:
  reg = bitfield_bit32_write(reg, ${field_name}_BIT, value);
%endif
  REG_WRITE32(address, reg);
}

${field_type} ${padframe.name}_${pad_domain.name}_${pad.name}_cfg_${ps.name}_get() {
  uint32_t address = ${padframe.name.upper()}_BASE_ADDRESS + ${address};
  uint32_t reg = REG_READ32(address);
  %if ps.size > 1:
  return bitfield_field32_read(reg, ${field_name}_FIELD);
%else:
  return bitfield_bit32_read(reg, ${field_name}_BIT);
%endif
}
% endfor
% if pad.dynamic_pad_signals_soc2pad:
<%
  address = f"{padframe.name.upper()}_{pad_domain.name.upper()}_CONFIG_{pad.name.upper()}_MUX_SEL_REG_OFFSET"
%>
void ${padframe.name}_${pad_domain.name}_${pad.name}_mux_set(${padframe.name}_${pad_domain.name}_${pad.name}_mux_sel_t mux_sel) {
  const uint32_t address = ${padframe.name.upper()}_BASE_ADDRESS + ${address};
##  const uint32_t sel_size = ${sel_size};
##  uint32_t field_mask = (1<<sel_size)-1;
##  REG_WRITE32(address, mux_sel & field_mask);
  REG_WRITE32(address, mux_sel & ${(1<<sel_size)-1});
}

${padframe.name}_${pad_domain.name}_${pad.name}_mux_sel_t ${padframe.name}_${pad_domain.name}_${pad.name}_mux_get() {
  const uint32_t address = ${padframe.name.upper()}_BASE_ADDRESS + ${address};
##  const uint32_t sel_size = ${sel_size};

##  uint32_t field_mask = (1<<sel_size)-1;
##  return REG_READ32(address) & field_mask;
  return REG_READ32(address) & ${(1<<sel_size)-1};
}
% endif
% endfor
% endfor
