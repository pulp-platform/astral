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
#ifndef ${padframe.name.upper()}_H
#define ${padframe.name.upper()}_H
#include <stdint.h>

#ifndef ${padframe.name.upper()}_BASE_ADDRESS
#error "${padframe.name.upper()}_BASE_ADDRESS is not defined. Set this token to the configuration base address of your padframe before you include this header file."
#endif


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

  def sort_by_name(seq):
    return natsorted(seq, lambda x: x.name)
%>
/**
 * Sets the ${ps.name} pad signal for the pad: ${pad.name}
 *
 * @param value The value to program into the pad configuration register. A value smaller than ${2**ps.size-1}.
 */
void ${padframe.name}_${pad_domain.name}_${pad.name}_cfg_${ps.name}_set(${field_type} value);

/**
 * Get the currently configured ${ps.name} value for the pad: ${pad.name}
 *
 * @return The value of the ${ps.name} field
 */
${field_type} ${padframe.name}_${pad_domain.name}_${pad.name}_cfg_${ps.name}_get();
% endfor
% if pad.dynamic_pad_signals_soc2pad:

typedef enum {
  ${padframe.name.upper()}_${pad_domain.name.upper()}_${pad.name.upper()}_REGISTER = 0,
<% idx = 1 %>\
% for port_group in sort_by_name(pad_domain.port_groups):
% for port in sort_by_name(port_group.ports):
% if port.mux_groups.intersection(pad.mux_groups):
  ${padframe.name.upper()}_${pad_domain.name.upper()}_${pad.name.upper()}_group_${port_group.name.upper()}_port_${port.name.upper()} = ${idx},
<% idx += 1 %>\
% endif
% endfor
% endfor
} ${padframe.name}_${pad_domain.name}_${pad.name}_mux_sel_t;

/**
   * Choose the entity (a port or the dedicated configuration register) that controls ${pad.name}.
   *
   * @param mux_sel Port or configuration register to connect to the pad.
 */
void ${padframe.name}_${pad_domain.name}_${pad.name}_mux_set(${padframe.name}_${pad_domain.name}_${pad.name}_mux_sel_t mux_sel);

/**
 * Read the current multiplexer select value configured for ${pad.name}.
 *
 * @return Port or configuration register currently connected to the pad.
 */
 ${padframe.name}_${pad_domain.name}_${pad.name}_mux_sel_t ${padframe.name}_${pad_domain.name}_${pad.name}_mux_get();


% endif
% endfor
% endfor


#endif /*  ${padframe.name.upper()}_H */
