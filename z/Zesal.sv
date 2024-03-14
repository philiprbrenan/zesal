`define Reset        1  /* Zero all memory sizes                               */
`define Find         2  /* Find a key                                          */
`define Found        3  /* Found a key                                         */
`define ShiftUp      4  /* Shift the index up   1 at the specified offset to make room for a new entry  */
`define ShiftDown    5  /* Shift the index down 1 at the specified offset to remove an entry */

module Zesal
#(parameter integer KEYS_BITS     = 8,                                          // Number of bits in a key
  parameter integer DATA_BITS     = 8,                                          // Number of bits in the data corresponding with a key
  parameter integer NEXT_BITS     = 8,                                          // Number of bits in the pointer to the Zesal node
  parameter integer INDEX_BITS    = 8,                                          // Number of bits used to index within this Zesal node giving the number of elements that can be stored in one zesal node
  parameter integer  IN_BITS      = 8*64,                                       // Width of input data
  parameter integer  IN_CMD_BITS  = 8,                                          // Width of input command in data
  parameter integer OUT_BITS      = 8*64,                                       // Width of output data
  parameter integer OUT_CMD_BITS  = 8)                                          // Width of input command in data
 (input wire reset,                                                             // Width of output command
  input wire clock,                                                             // Clock
  input wire [ IN_BITS:0]in,                                                    // Input data
  output reg [OUT_BITS:0]out);                                                  // Output data

  localparam integer INDEX_LENGTH = 2**INDEX_BITS;                              // Maximum number of entries in this Zesal node

  reg [INDEX_BITS-1:0] index    [INDEX_LENGTH:0];                               // Index
  reg [INDEX_BITS-1:0] indexCopy[INDEX_LENGTH:0];                               // Copy of index during shift operations
  reg [KEYS_BITS -1:0] keys     [INDEX_LENGTH:0];                               // Keys
  reg [DATA_BITS -1:0] data     [INDEX_LENGTH:0],   dataFound;                  // Data storage, data found
  reg [NEXT_BITS -1:0] next     [INDEX_LENGTH+1:0], nextFound;                  // Next storage, next found

  assign in_cmd    = in[IN_CMD_BITS-1:0];                                       // The current command we are processing
  assign keySought = in[KEYS_BITS +IN_CMD_BITS-1:IN_CMD_BITS];                  // The key we are looking for
  assign shiftBy   = in[INDEX_BITS+IN_CMD_BITS-1:IN_CMD_BITS];                  // The shift point

  reg [OUT_CMD_BITS -1:0] out_cmd;                                              // Output command
  assign out = {out_cmd, dataFound};                                            // Output area

  integer used;                                                                 // Triples used so far
  integer i, j;                                                                 // Indices

  always @(posedge clock) begin                                                 // Each transition
    case(in_cmd)                                                                // Decode request
      `Reset: begin                                                             // Reset
        used = 0;
      end
      `Find: begin                                                              // Find a key by searching every triple in parallel
        for(i = 0; i < INDEX_LENGTH; ++i) begin
          if (i < used) begin                                                   // Active area if Zesal node
            if (keys[index[i]] == keySought) begin
              out_cmd = `Found;
              dataFound = data[index[i]];
              nextFound = next[index[i]];
            end
          end
        end
      end
      `ShiftUp: begin                                                           // Shift up from the specified index
        if (used > 0) begin
          for(i = 0; i < INDEX_LENGTH; ++i) begin                               // Copy index
            indexCopy[i] = index[i];
          end
          for(i = 0; i < INDEX_LENGTH; ++i) begin                               // Shift
            if (i < used && i >= shiftBy) begin                                 // In area to be shifted
              index[i+1] = indexCopy[i];
            end
          end
          used++;
        end
      end
      `ShiftDown: begin                                                         // Shift down to the specified index
        if (used > 0) begin
          for(i = 0; i < INDEX_LENGTH; ++i) begin                               // Copy index
            indexCopy[i] = index[i];
          end
          for(i = 0; i < INDEX_LENGTH; ++i) begin                               // Shift
            if (i < used && i >= shiftBy) begin                                 // In area to be shifted
              index[i] = indexCopy[i + 1];
            end
          end
          used--;
        end
      end
    endcase
  end
endmodule
