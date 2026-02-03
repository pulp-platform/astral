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

% for line in header_text.splitlines():
// ${line}
% endfor
module ${padframe.name}_${pad_domain.name}
  import pkg_${padframe.name}::*;
  import pkg_internal_${padframe.name}_${pad_domain.name}::*;
#(
  parameter type              req_t  = logic, // reg_interface request type
  parameter type             resp_t  = logic // reg_interface response type
) (
  input logic clk_i,
  input logic rst_ni,
% if pad_domain.override_signals:
  input pad_domain_${pad_domain.name}_override_signals_t override_signals_i,
% endif
% if pad_domain.static_connection_signals_pad2soc:
  output pad_domain_${pad_domain.name}_static_connection_signals_pad2soc_t static_connection_signals_pad2soc,
% endif
% if pad_domain.static_connection_signals_soc2pad:
  input pad_domain_${pad_domain.name}_static_connection_signals_soc2pad_t static_connection_signals_soc2pad,
% endif
% if any([port_group.port_signals_pads2soc for port_group in pad_domain.port_groups]):
  output pad_domain_${pad_domain.name}_ports_pad2soc_t port_signals_pad2soc_o,
% endif
% if any([port_group.port_signals_soc2pads for port_group in pad_domain.port_groups]):
  input pad_domain_${pad_domain.name}_ports_soc2pad_t port_signals_soc2pad_i,
% endif
% for pad in pad_domain.pad_list:
% for i in range(pad.multiple):
<% pad_suffix = i if pad.multiple > 1 else "" %>\
% for signal in pad.landing_pads:
  inout wire logic pad_${pad.name}${pad_suffix}_${signal.name},
% endfor
% endfor
% endfor
  input req_t config_req_i,
  output resp_t config_rsp_o
);

% if any([pad.dynamic_pad_signals_soc2pad for pad in pad_domain.pad_list]):
   mux_to_pads_t s_mux_to_pads;
% endif
% if any([pad.dynamic_pad_signals_pad2soc for pad in pad_domain.pad_list]):
   pads_to_mux_t s_pads_to_mux;

% endif
   ${padframe.name}_${pad_domain.name}_pads i_${pad_domain.name}_pads (
% if pad_domain.override_signals:
     .override_signals_i,
% endif
% if pad_domain.static_connection_signals_pad2soc:
     .static_connection_signals_pad2soc,
% endif
% if pad_domain.static_connection_signals_soc2pad:
     .static_connection_signals_soc2pad,
% endif
% if any([pad.dynamic_pad_signals_soc2pad for pad in pad_domain.pad_list]):
     .mux_to_pads_i(s_mux_to_pads),
% endif
% if any([pad.dynamic_pad_signals_pad2soc for pad in pad_domain.pad_list]):
     .pads_to_mux_o(s_pads_to_mux),
% endif
<%
  port_list = []
  for pad in pad_domain.pad_list:
      for i in range(pad.multiple):
          pad_suffix = i if pad.multiple > 1 else ""
          for signal in pad.landing_pads:
              port_list.append(f".pad_{pad.name}{pad_suffix}_{signal.name}")
  ports = ",\n".join(port_list)
%>\
% for line in ports.splitlines():
     ${line}
% endfor

  );

   ${padframe.name}_${pad_domain.name}_muxer #(
     .req_t(req_t),
     .resp_t(resp_t)
   )i_${pad_domain.name}_muxer (
     .clk_i,
     .rst_ni,
% if any([port_group.port_signals_soc2pads for port_group in pad_domain.port_groups]):
     .port_signals_soc2pad_i,
% endif
% if any([port_group.port_signals_pads2soc for port_group in pad_domain.port_groups]):
     .port_signals_pad2soc_o,
% endif
% if any([pad.dynamic_pad_signals_soc2pad for pad in pad_domain.pad_list]):
     .mux_to_pads_o(s_mux_to_pads),
% endif
% if any([pad.dynamic_pad_signals_soc2pad for pad in pad_domain.pad_list]):
     .pads_to_mux_i(s_pads_to_mux),
% endif
     // Configuration interface using register_interface protocol
     .config_req_i,
     .config_rsp_o
   );

endmodule : ${padframe.name}_${pad_domain.name}
