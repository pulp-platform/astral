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
# ${line}
% endfor
${padframe.name}:
  files:
    - src/${templates.toplevel_sv_package.target_file_name.format(padframe=padframe)}
% for pad_domain in padframe.pad_domains:
    - src/${templates.internal_pkg.target_file_name.format(padframe=padframe, pad_domain = pad_domain)}
    - src/${padframe.name}_${pad_domain.name}_config_reg_pkg.sv
    - src/${padframe.name}_${pad_domain.name}_config_reg_top.sv
    - src/${templates.pad_inst_module.target_file_name.format(padframe=padframe, pad_domain = pad_domain)}
    - src/${templates.pad_mux_module.target_file_name.format(padframe=padframe, pad_domain = pad_domain)}
    - src/${templates.pad_domain_top.target_file_name.format(padframe=padframe, pad_domain = pad_domain)}
% endfor
    - src/${templates.toplevel_module.target_file_name.format(padframe=padframe)}
  vlog_opts:
    - -L axi_lib