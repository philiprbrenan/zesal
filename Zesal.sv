`define Reset        1  /* Zero all memory sizes                               */
`define Write        2  /* Write an element                                    */
`define Read         3  /* Read an element                                     */
`define Size         4  /* Size of array                                       */
`define Inc          5  /* Increment size of array if possible                 */
`define Dec          6  /* Decrement size of array if possible                 */
`define Index        7  /* Index of element in array                           */
`define Less         8  /* Elements of array less than in                      */
`define Greater      9  /* Elements of array greater than in                   */
`define Up          10  /* Move array up                                       */
`define Down        11  /* Move array down                                     */
`define Long1       12  /* Move long first step                                */
`define Long2       13  /* Move long last  step                                */
`define Push        14  /* Push if possible                                    */
`define Pop         15  /* Pop if possible                                     */
`define Dump        16  /* Dump                                                */
`define Resize      17  /* Resize an array                                     */
`define Alloc       18  /* Allocate a new array before using it                */
`define Free        19  /* Free an array for reuse                             */
`define Add         20  /* Add to an element returning the new value           */
`define AddAfter    21  /* Add to an element returning the previous value      */
`define Subtract    22  /* Subtract to an element returning the new value      */
`define SubAfter    23  /* Subtract to an element returning the previous value */
`define ShiftLeft   24  /* Shift left                                          */
`define ShiftRight  25  /* Shift right                                         */
`define NotLogical  26  /* Not - logical                                       */
`define Not         27  /* Not - bitwise                                       */
`define Or          28  /* Or                                                  */
`define Xor         29  /* Xor                                                 */
`define And         30  /* And                                                 */


module Zesal
#(parameter integer KEYS_BITS  = 8,                                             // Number of bits in a key
  parameter integer DATA_BITS  = 8,                                             // Number of bits in the data corresponding with a key
  parameter integer NEXT_BITS  = 8,                                             // Number of bits in the pointer to the Zesal node
  parameter integer INDEX_BITS = 8,                                             // Number of bits used to index within this Zesal node giving the number of elements that can be stored in one zesal node
  parameter integer  IN_BITS   = 8*64,                                          // Width of input data
  parameter integer OUT_BITS   = 8*64)                                          // Width of output data
 (input wire reset,                                                             // Reset when high, operate when low
  input wire clock,                                                             // Clock
  input wire [ IN_BITS:0]in ,                                                   // Input data
  output reg [OUT_BITS:0]out);                                                  // Output data

  localparam integer INDEX_LENGTH = 2**INDEX_BITS;                              // Maximum number of entries in this Zesal node

  reg [INDEX_BITS  -1:0] index[INDEX_LENGTH:0];                                 // Index
  reg [KEYS_BITS   -1:0] keys[INDEX_LENGTH:0];                                  // Keys
  reg [DATA_BITS   -1:0] data[INDEX_LENGTH:0];                                  // Data
  reg [NEXT_BITS   -1:0] next[INDEX_LENGTH+1:0];                                // Next

  integer used;                                                                 // Triples used so far

  always @(posedge clock) begin                                                 // Each transition
    case(in)                                                                    // Decode request
      `Reset: begin                                                             // Reset
        used = 0;
      end
    endcase
  end
endmodule
