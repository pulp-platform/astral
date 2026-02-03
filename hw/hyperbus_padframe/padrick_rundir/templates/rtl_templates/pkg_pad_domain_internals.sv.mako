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
// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

% for line in header_text.splitlines():
// ${line}
% endfor
package pkg_internal_${padframe.name}_${pad_domain.name};
% for pad in pad_domain.pad_list:
% if pad.dynamic_pad_signals_soc2pad:
  typedef struct packed{
% for signal in pad.dynamic_pad_signals_soc2pad:
    logic ${f"[{signal.size-1}:0]" if signal.size > 1 else ""} ${signal.name};
% endfor
  } mux_to_pad_${pad.name}_t;

% endif
% if pad.dynamic_pad_signals_pad2soc:
  typedef struct packed{
% for signal in pad.dynamic_pad_signals_pad2soc:
    logic ${f"[{signal.size-1}:0]" if signal.size > 1 else ""} ${signal.name};
% endfor
  } pad_to_mux_${pad.name}_t;

% endif
% endfor
% if any([pad.dynamic_pad_signals_soc2pad for pad in pad_domain.pad_list]):
  typedef struct packed{
% for pad in pad_domain.pad_list:
% if pad.dynamic_pad_signals_soc2pad:
    mux_to_pad_${pad.name}_t ${pad.name};
% endif
% endfor
  } mux_to_pads_t;

% endif
% if any([pad.dynamic_pad_signals_pad2soc for pad in pad_domain.pad_list]):
  typedef struct packed{
% for pad in pad_domain.pad_list:
% if pad.dynamic_pad_signals_pad2soc:
    pad_to_mux_${pad.name}_t ${pad.name};
% endif
% endfor
  } pads_to_mux_t;

% endif


  // Indices definitions
% for mux_groups in pad_domain.pad_mux_group_sets:
<%
import math
from natsort import natsorted
mux_group_name = "_".join(natsorted(mux_groups)).upper()
all_ports_in_mux_group = pad_domain.get_ports_in_mux_groups(mux_groups)
sel_bitwidth = max(1,math.ceil(math.log2(len(all_ports_in_mux_group)+1))) # +1 since the sel == 0 in this case means "use config register value" which is the default
idx = 1
def sort_by_name(seq):
    return natsorted(seq, lambda x: x.name)
%>\

  parameter PAD_MUX_GROUP_${mux_group_name}_SEL_WIDTH = ${sel_bitwidth};
  parameter logic[${sel_bitwidth-1}:0] PAD_MUX_GROUP_${mux_group_name}_SEL_DEFAULT = ${sel_bitwidth}'d0;
% for port_group in sort_by_name(pad_domain.port_groups):
% for port in sort_by_name(port_group.ports):
% if port.mux_groups.intersection(mux_groups):
  parameter logic[${sel_bitwidth-1}:0] PAD_MUX_GROUP_${mux_group_name}_SEL_${port_group.name.upper()}_${port.name.upper()} = ${sel_bitwidth}'d${idx};
<% idx += 1 %>\
% endif
% endfor
% endfor
% endfor

  // Dynamic Pad  instance index
% for mux_groups in pad_domain.port_mux_group_sets:
<%
  mux_group_name = "_".join(natsorted(mux_groups)).upper()
  dynamic_pads = pad_domain.get_dynamic_pads_in_mux_groups(mux_groups)
  sel_bitwidth = max(1, math.ceil(math.log2(len(dynamic_pads)))) # no +1 here since the default is activate if the empty_o signal of the leading zero counter is asserted.
  idx = 0
%>
  parameter PORT_MUX_GROUP_${mux_group_name}_SEL_WIDTH = ${sel_bitwidth};
% for pad in dynamic_pads:
  parameter logic[${sel_bitwidth-1}:0] PORT_MUX_GROUP_${mux_group_name}_SEL_${pad.name.upper()} = ${sel_bitwidth}'d${idx};
<% idx += 1 %>\
% endfor
% endfor
endpackage : pkg_internal_${padframe.name}_${pad_domain.name}
