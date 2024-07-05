// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Behavioural models of the pads used by Astral's padframe
//
// Author: Victor Isachi <victor.isachi@unibo.it>

module PDVDDTIE_18_18_NT_DR_H (
   output logic SNS,
   output logic RTO
);

   assign SNS = 1'b1;
   assign RTO = 1'b1;

endmodule: PDVDDTIE_18_18_NT_DR_H

module PVDD_08_08_NT_DR_H ();
endmodule: PVDD_08_08_NT_DR_H

module PVDD_08_08_NT_DR_V ();
endmodule: PVDD_08_08_NT_DR_V

module PVSS_08_08_NT_DR_H ();
endmodule: PVSS_08_08_NT_DR_H

module PVSS_08_08_NT_DR_V ();
endmodule: PVSS_08_08_NT_DR_V

module PDVDD_18_18_NT_DR_H ();
endmodule: PDVDD_18_18_NT_DR_H

module PDVDD_18_18_NT_DR_V ();
endmodule: PDVDD_18_18_NT_DR_V

module PDVSS_18_18_NT_DR_H ();
endmodule: PDVSS_18_18_NT_DR_H

module PDVSS_18_18_NT_DR_V ();
endmodule: PDVSS_18_18_NT_DR_V

module PCORNER_18_18_NT_DR ();
endmodule: PCORNER_18_18_NT_DR


module POSCP_18_18_NT_DR_H (
   output logic CK,
   output logic CK_IOV,
   output logic PO,
   input  logic PADO,
   input  logic E0,
   input  logic PADI,
   input  logic POE,
   input  logic RTO,
   input  logic SF0,
   input  logic SF1,
   input  logic SNS,
   input  logic SP,
   input  logic TE
);

   buf(CK, PADI);
   buf(CK_IOV, PADI);

endmodule: POSCP_18_18_NT_DR_H

module PBIDIR_18_18_NT_DR_H (
   output logic PO, 
   output logic Y,
   inout  logic PAD,
   input  logic A,
   input  logic DS0,
   input  logic DS1,
   input  logic IE, 
   input  logic IS, 
   input  logic OE, 
   input  logic PE, 
   input  logic POE,
   input  logic PS, 
   input  logic RTO,
   input  logic SNS,
   input  logic SR
);

   bufif1 (PAD, A, OE);
   bufif1 (Y, PAD, IE);

endmodule: PBIDIR_18_18_NT_DR_H

module PBIDIR_18_18_NT_DR_V (
   output logic PO, 
   output logic Y,
   inout  logic PAD,
   input  logic A,
   input  logic DS0,
   input  logic DS1,
   input  logic IE, 
   input  logic IS, 
   input  logic OE, 
   input  logic PE, 
   input  logic POE,
   input  logic PS, 
   input  logic RTO,
   input  logic SNS,
   input  logic SR
);

   bufif1 (PAD, A, OE);
   bufif1 (Y, PAD, IE);

endmodule: PBIDIR_18_18_NT_DR_V
