//-----------------------------------------------------------------------------
// Check test results
// Philip R Brenan at appaapps dot com, Appa Apps Ltd Inc., 2023
//------------------------------------------------------------------------------
integer testsPassed = 0;                                                        // Tests passed
integer testsFailed = 0;                                                        // Tests failed

task ok(integer signed test, string name);                                      // Check a single test result
  begin
    if (test == 1) begin
      testsPassed++;
    end
    else begin
      $display("Assertion %s FAILED", name);
      testsFailed++;
    end
  end
endtask

task checkAllTestsPassed(integer NTestsExpected);                               // Check we got the expected number of passes
  begin
    if (testsPassed > 0 && testsFailed > 0) begin                               // Summarize test results
       $display("Passed %1d tests, FAILED %1d tests out of %d tests",  testsPassed, testsFailed, NTestsExpected);
       $finish();
    end
    else if (testsFailed > 0) begin
       $display("FAILED %1d tests out of %1d tests", testsFailed, NTestsExpected);
       $finish();
    end
    else if (testsPassed > 0 && testsPassed != NTestsExpected) begin
       $display("Passed %1d tests out of %1d tests with no failures ", testsPassed, NTestsExpected);
       $finish();
    end
    else if (testsPassed == NTestsExpected) begin                               // Testing summary
       $display("All %1d tests passed successfully", NTestsExpected);
       $finish();
    end
    else begin
       $display("No tests run passed: %1d, failed: %1d, expected %1d", testsPassed, testsFailed, NTestsExpected);
       $finish();
    end
  end
endtask
