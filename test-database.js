// Test script to verify database setup
// Run this in your browser console on the admin page

async function testDatabase() {
  console.log('Testing database connectivity...');
  
  try {
    // Test 1: Check if we can load employees
    console.log('Test 1: Loading employees...');
    const employees = await dataService.getEmployees();
    console.log('✅ Employees loaded:', employees);
    
    // Test 2: Check if we can create an employee
    console.log('Test 2: Creating test employee...');
    const testEmployee = {
      name: 'Test Employee',
      email: 'test@example.com',
      phone: '+1234567890',
      password: 'testpass123',
      annual_leave_remaining: 15,
      sick_leave_remaining: 10
    };
    
    const createdEmployee = await dataService.saveEmployee(testEmployee);
    console.log('✅ Test employee created:', createdEmployee);
    
    // Test 3: Check if we can update the employee
    console.log('Test 3: Updating test employee...');
    const updatedEmployee = await dataService.updateEmployee(createdEmployee.id, {
      name: 'Updated Test Employee',
      phone: '+0987654321'
    });
    console.log('✅ Test employee updated:', updatedEmployee);
    
    // Test 4: Check if we can update vacation balance
    console.log('Test 4: Updating vacation balance...');
    const vacationUpdated = await dataService.updateEmployeeVacationBalance(
      createdEmployee.id,
      10,
      5
    );
    console.log('✅ Vacation balance updated:', vacationUpdated);
    
    // Test 5: Check if we can delete the employee
    console.log('Test 5: Deleting test employee...');
    await dataService.deleteEmployee(createdEmployee.id);
    console.log('✅ Test employee deleted');
    
    console.log('🎉 All database tests passed!');
    
  } catch (error) {
    console.error('❌ Database test failed:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      details: error.details,
      hint: error.hint
    });
  }
}

// Run the test
testDatabase(); 