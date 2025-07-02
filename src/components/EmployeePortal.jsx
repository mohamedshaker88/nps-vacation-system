import React, { useState, useEffect } from 'react';
import { Calendar, Clock, User, Send, CheckCircle, XCircle, AlertCircle, FileText, Phone, Mail, LogOut, Eye, EyeOff } from 'lucide-react';
import { dataService } from '../services/dataService';

const EmployeePortal = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentEmployee, setCurrentEmployee] = useState(null);
  const [showLogin, setShowLogin] = useState(true);
  const [showRegister, setShowRegister] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [registerForm, setRegisterForm] = useState({ 
    name: '', 
    email: '', 
    phone: '', 
    password: '', 
    confirmPassword: '' 
  });
  const [authError, setAuthError] = useState('');

  const [myRequests, setMyRequests] = useState([]);
  const [teammates, setTeammates] = useState([]);
  const [newRequest, setNewRequest] = useState({
    type: '',
    startDate: '',
    endDate: '',
    reason: '',
    coverageBy: '',
    emergencyContact: '',
    additionalNotes: '',
    medicalCertificate: false
  });

  const [showRequestForm, setShowRequestForm] = useState(false);
  const [activeTab, setActiveTab] = useState('overview');

  const [policy, setPolicy] = useState(null);
  const [policyLoading, setPolicyLoading] = useState(false);
  const [policyError, setPolicyError] = useState('');

  const leaveTypes = [
    { value: 'Annual Leave', label: 'Annual Leave', maxDays: 14, paid: true, description: 'Paid vacation time' },
    { value: 'Sick Leave', label: 'Sick Leave', maxDays: 1, paid: true, description: 'Paid sick day (1 day maximum per request)' },
    { value: 'Emergency Leave', label: 'Emergency Leave', maxDays: 3, paid: false, description: 'Unpaid emergency leave' },
    { value: 'Personal Leave', label: 'Personal Day', maxDays: 1, paid: false, description: 'Unpaid personal day' },
    { value: 'Maternity Leave', label: 'Maternity Leave', maxDays: 70, paid: false, description: 'Unpaid maternity leave' },
    { value: 'Paternity Leave', label: 'Paternity Leave', maxDays: 7, paid: false, description: 'Unpaid paternity leave' },
    { value: 'Bereavement Leave', label: 'Bereavement Leave', maxDays: 5, paid: false, description: 'Unpaid bereavement leave' },
    { value: 'Religious Leave', label: 'Religious Leave', maxDays: 2, paid: false, description: 'Unpaid religious observance' },
    { value: 'Compensatory Time', label: 'Comp Time', maxDays: 3, paid: false, description: 'Unpaid compensation time' }
  ];

  // Load data from Supabase
  useEffect(() => {
    const savedAuth = localStorage.getItem('employeeAuth');
    const savedEmployee = localStorage.getItem('currentEmployee');
    
    if (savedAuth === 'true' && savedEmployee) {
      const employee = JSON.parse(savedEmployee);
      setIsAuthenticated(true);
      setCurrentEmployee(employee);
      loadEmployeeData(employee);
    }
  }, []);

  const loadEmployeeData = async (employee) => {
    try {
      setLoading(true);
      // Load requests for this employee
      const employeeRequests = await dataService.getRequestsByEmployee(employee.email);
      setMyRequests(employeeRequests);

      // Load all employees for coverage selection
      const allEmployees = await dataService.getEmployees();
      const otherEmployees = allEmployees.filter(emp => emp.email !== employee.email);
      setTeammates(otherEmployees);
    } catch (error) {
      console.error('Error loading employee data:', error);
    } finally {
      setLoading(false);
    }
  };

  const validateEmail = (email) => {
    return email.toLowerCase().endsWith('@technetworkinc.com');
  };

  const handleRegister = async () => {
    setAuthError('');

    // Validation
    if (!registerForm.name || !registerForm.email || !registerForm.phone || !registerForm.password) {
      setAuthError('Please fill in all fields');
      return;
    }

    if (!validateEmail(registerForm.email)) {
      setAuthError('You must use your company email (@technetworkinc.com)');
      return;
    }

    if (registerForm.password !== registerForm.confirmPassword) {
      setAuthError('Passwords do not match');
      return;
    }

    if (registerForm.password.length < 6) {
      setAuthError('Password must be at least 6 characters');
      return;
    }

    try {
      // Check if email already exists
      const emailExists = await dataService.checkEmailExists(registerForm.email);
      if (emailExists) {
        setAuthError('An account with this email already exists');
        return;
      }

      // Create new employee
      const newEmployee = {
        name: registerForm.name,
        email: registerForm.email,
        phone: registerForm.phone,
        password: registerForm.password, // In real app, this would be hashed
        created_at: new Date().toISOString()
      };

      // Save to Supabase
      await dataService.saveEmployee(newEmployee);

      // Auto login
      setCurrentEmployee(newEmployee);
      setIsAuthenticated(true);
      localStorage.setItem('employeeAuth', 'true');
      localStorage.setItem('currentEmployee', JSON.stringify(newEmployee));
      
      loadEmployeeData(newEmployee);
    } catch (error) {
      console.error('Error registering:', error);
      setAuthError('Error creating account. Please try again.');
    }
  };

  const handleLogin = async () => {
    setAuthError('');

    if (!loginForm.email || !loginForm.password) {
      setAuthError('Please fill in all fields');
      return;
    }

    if (!validateEmail(loginForm.email)) {
      setAuthError('You must use your company email (@technetworkinc.com)');
      return;
    }

    try {
      // Check credentials
      const employee = await dataService.authenticateEmployee(loginForm.email, loginForm.password);

      if (!employee) {
        setAuthError('Invalid email or password');
        return;
      }

      // Login successful
      setCurrentEmployee(employee);
      setIsAuthenticated(true);
      localStorage.setItem('employeeAuth', 'true');
      localStorage.setItem('currentEmployee', JSON.stringify(employee));
      
      loadEmployeeData(employee);
    } catch (error) {
      console.error('Error logging in:', error);
      setAuthError('Invalid email or password');
    }
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    setCurrentEmployee(null);
    localStorage.removeItem('employeeAuth');
    localStorage.removeItem('currentEmployee');
    setLoginForm({ email: '', password: '' });
    setRegisterForm({ name: '', email: '', phone: '', password: '', confirmPassword: '' });
  };

  const calculateDays = (start, end) => {
    if (!start || !end) return 0;
    const startDate = new Date(start);
    const endDate = new Date(end);
    const diffTime = Math.abs(endDate - startDate);
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
  };

  const handleSubmitRequest = async () => {
    if (!newRequest.type || !newRequest.startDate || !newRequest.endDate || !newRequest.reason) {
      alert('Please fill in all required fields');
      return;
    }

    const selectedLeaveType = leaveTypes.find(type => type.value === newRequest.type);
    const days = calculateDays(newRequest.startDate, newRequest.endDate);
    
    // Validate sick leave restriction
    if (newRequest.type === 'Sick Leave' && days > 1) {
      alert('Sick leave cannot exceed 1 day per request. For longer illnesses, please submit multiple single-day requests.');
      return;
    }

    // Validate maximum days
    if (days > selectedLeaveType.maxDays) {
      alert(`${selectedLeaveType.label} cannot exceed ${selectedLeaveType.maxDays} days per request.`);
      return;
    }

    const request = {
      employee_name: currentEmployee.name,
      employee_email: currentEmployee.email,
      type: newRequest.type,
      start_date: newRequest.startDate,
      end_date: newRequest.endDate,
      days: days,
      reason: newRequest.reason,
      status: 'Pending',
      submit_date: new Date().toISOString().split('T')[0],
      coverage_by: newRequest.coverageBy,
      emergency_contact: newRequest.emergencyContact,
      additional_notes: newRequest.additionalNotes,
      medical_certificate: newRequest.medicalCertificate
    };

    try {
      // Save to Supabase
      const newRequestData = await dataService.saveRequest(request);
      
      // Update local state
      setMyRequests([newRequestData, ...myRequests]);
      setNewRequest({
        type: '',
        startDate: '',
        endDate: '',
        reason: '',
        coverageBy: '',
        emergencyContact: '',
        additionalNotes: '',
        medicalCertificate: false
      });
      setShowRequestForm(false);
      alert('Leave request submitted successfully!');
    } catch (error) {
      console.error('Error submitting request:', error);
      alert('Error submitting request. Please try again.');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'Approved': return 'text-green-600 bg-green-100';
      case 'Rejected': return 'text-red-600 bg-red-100';
      case 'Pending': return 'text-yellow-600 bg-yellow-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  // Calculate leave balances using dynamic policy
  const usedAnnual = myRequests.filter(r => 
    r.type === 'Annual Leave' && r.status === 'Approved'
  ).reduce((sum, r) => sum + r.days, 0);
  
  const usedSick = myRequests.filter(r => 
    r.type === 'Sick Leave' && r.status === 'Approved'
  ).reduce((sum, r) => sum + r.days, 0);

  const annualLeaveEntitlement = policy?.entitlements?.annualLeave || 15;
  const sickLeaveEntitlement = policy?.entitlements?.sickLeave || 10;
  const dynamicLeaveTypes = policy?.leaveTypes || leaveTypes; // Fallback to hardcoded if no policy

  // Authentication forms
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="max-w-md w-full bg-white rounded-lg shadow-md p-6">
          <div className="text-center mb-6">
            <h1 className="text-2xl font-bold text-gray-900">Employee Portal</h1>
            <p className="text-gray-600">NPS Team Vacation System</p>
          </div>
          
          {showLogin ? (
            <div className="space-y-4">
              <h2 className="text-lg font-semibold text-center">Login</h2>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Company Email</label>
                <input
                  type="email"
                  value={loginForm.email}
                  onChange={(e) => setLoginForm({...loginForm, email: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="your.name@technetworkinc.com"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                <div className="relative">
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={loginForm.password}
                    onChange={(e) => setLoginForm({...loginForm, password: e.target.value})}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 pr-10 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter password"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute inset-y-0 right-0 pr-3 flex items-center"
                  >
                    {showPassword ? <EyeOff className="h-4 w-4 text-gray-400" /> : <Eye className="h-4 w-4 text-gray-400" />}
                  </button>
                </div>
              </div>
              
              {authError && (
                <div className="text-red-600 text-sm">{authError}</div>
              )}
              
              <button
                onClick={handleLogin}
                className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition duration-200"
              >
                Login
              </button>
              
              <div className="text-center">
                <button
                  onClick={() => { setShowLogin(false); setAuthError(''); }}
                  className="text-blue-600 hover:text-blue-800 text-sm"
                >
                  Don't have an account? Register here
                </button>
              </div>
            </div>
          ) : (
            <div className="space-y-4">
              <h2 className="text-lg font-semibold text-center">Create Account</h2>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                <input
                  type="text"
                  value={registerForm.name}
                  onChange={(e) => setRegisterForm({...registerForm, name: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Enter your full name"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Company Email</label>
                <input
                  type="email"
                  value={registerForm.email}
                  onChange={(e) => setRegisterForm({...registerForm, email: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="your.name@technetworkinc.com"
                />
                <p className="text-xs text-gray-500 mt-1">Must use your @technetworkinc.com email</p>
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Mobile Number</label>
                <input
                  type="tel"
                  value={registerForm.phone}
                  onChange={(e) => setRegisterForm({...registerForm, phone: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Enter your mobile number"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
                <input
                  type="password"
                  value={registerForm.password}
                  onChange={(e) => setRegisterForm({...registerForm, password: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="At least 6 characters"
                />
              </div>
              
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
                <input
                  type="password"
                  value={registerForm.confirmPassword}
                  onChange={(e) => setRegisterForm({...registerForm, confirmPassword: e.target.value})}
                  className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  placeholder="Confirm your password"
                />
              </div>
              
              {authError && (
                <div className="text-red-600 text-sm">{authError}</div>
              )}
              
              <button
                onClick={handleRegister}
                className="w-full bg-green-600 text-white py-2 px-4 rounded-md hover:bg-green-700 transition duration-200"
              >
                Create Account
              </button>
              
              <div className="text-center">
                <button
                  onClick={() => { setShowLogin(true); setAuthError(''); }}
                  className="text-blue-600 hover:text-blue-800 text-sm"
                >
                  Already have an account? Login here
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    );
  }

  const renderOverview = () => (
    <div className="space-y-6">
      {loading && (
        <div className="text-center py-4">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-2 text-gray-600">Loading data...</p>
        </div>
      )}
      
      <div className="bg-white rounded-lg shadow-sm border p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-3">
            <div className="bg-blue-100 p-3 rounded-full">
              <User className="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h2 className="text-xl font-semibold">Welcome, {currentEmployee.name}</h2>
              <p className="text-gray-600">{currentEmployee.email}</p>
            </div>
          </div>
          <div className="text-right">
            <p className="text-sm text-gray-600">{currentEmployee.phone}</p>
            <p className="text-sm text-gray-600">technetworkinc.com</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-blue-50 p-6 rounded-lg border border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-600 text-sm font-medium">Annual Leave</p>
              <p className="text-2xl font-bold text-blue-800">
                {annualLeaveEntitlement - usedAnnual}/{annualLeaveEntitlement}
              </p>
              <p className="text-xs text-blue-600">Days Remaining</p>
            </div>
            <Calendar className="h-8 w-8 text-blue-600" />
          </div>
          <div className="mt-3 w-full bg-blue-200 rounded-full h-2">
            <div 
              className="bg-blue-600 h-2 rounded-full" 
              style={{width: `${(usedAnnual / annualLeaveEntitlement) * 100}%`}}
            ></div>
          </div>
        </div>

        <div className="bg-green-50 p-6 rounded-lg border border-green-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-600 text-sm font-medium">Sick Leave</p>
              <p className="text-2xl font-bold text-green-800">
                {sickLeaveEntitlement - usedSick}/{sickLeaveEntitlement}
              </p>
              <p className="text-xs text-green-600">Days Remaining</p>
            </div>
            <FileText className="h-8 w-8 text-green-600" />
          </div>
          <div className="mt-3 w-full bg-green-200 rounded-full h-2">
            <div 
              className="bg-green-600 h-2 rounded-full" 
              style={{width: `${(usedSick / sickLeaveEntitlement) * 100}%`}}
            ></div>
          </div>
        </div>

        <div className="bg-purple-50 p-6 rounded-lg border border-purple-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-purple-600 text-sm font-medium">Pending Requests</p>
              <p className="text-2xl font-bold text-purple-800">
                {myRequests.filter(r => r.status === 'Pending').length}
              </p>
              <p className="text-xs text-purple-600">Awaiting Approval</p>
            </div>
            <Clock className="h-8 w-8 text-purple-600" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border">
        <div className="p-4 border-b flex items-center justify-between">
          <h3 className="text-lg font-semibold">Recent Requests</h3>
          <button
            onClick={() => setShowRequestForm(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
          >
            <Send className="h-4 w-4" />
            New Request
          </button>
        </div>
        <div className="p-4">
          {myRequests.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No requests submitted yet</p>
          ) : (
            myRequests.slice(0, 3).map(request => (
              <div key={request.id} className="flex items-center justify-between py-3 border-b last:border-b-0">
                <div>
                  <div className="font-medium">{request.type}</div>
                  <div className="text-sm text-gray-600">
                    {request.start_date} {request.start_date !== request.end_date ? `to ${request.end_date}` : ''} • {request.days} day{request.days > 1 ? 's' : ''}
                  </div>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(request.status)}`}>
                  {request.status}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );

  const renderRequestForm = () => (
    <div className="bg-white rounded-lg shadow-sm border">
      <div className="p-4 border-b flex items-center justify-between">
        <h3 className="text-lg font-semibold">Submit Leave Request</h3>
        <button
          onClick={() => setShowRequestForm(false)}
          className="text-gray-500 hover:text-gray-700"
        >
          <XCircle className="h-5 w-5" />
        </button>
      </div>
      
      <div className="p-6 space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Leave Type *</label>
          <select
            value={newRequest.type}
            onChange={(e) => setNewRequest({...newRequest, type: e.target.value})}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select Leave Type</option>
            {dynamicLeaveTypes.map(type => (
              <option key={type.value} value={type.value}>
                {type.label} - {type.paid ? 'Paid' : 'Unpaid'} (Max: {type.maxDays} days)
              </option>
            ))}
          </select>
          {newRequest.type && (
            <div className="mt-2 p-3 bg-blue-50 rounded-md">
              <p className="text-sm text-blue-800">
                {dynamicLeaveTypes.find(t => t.value === newRequest.type)?.description}
              </p>
            </div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Start Date *</label>
            <input
              type="date"
              value={newRequest.startDate}
              onChange={(e) => setNewRequest({...newRequest, startDate: e.target.value})}
              min={new Date().toISOString().split('T')[0]}
              className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">End Date *</label>
            <input
              type="date"
              value={newRequest.endDate}
              onChange={(e) => setNewRequest({...newRequest, endDate: e.target.value})}
              min={newRequest.startDate || new Date().toISOString().split('T')[0]}
              className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        </div>

        {newRequest.startDate && newRequest.endDate && (
          <div className="bg-blue-50 p-3 rounded-md">
            <p className="text-sm text-blue-800">
              Total days requested: {calculateDays(newRequest.startDate, newRequest.endDate)}
              {newRequest.type === 'Sick Leave' && calculateDays(newRequest.startDate, newRequest.endDate) > 1 && (
                <span className="text-red-600 block mt-1">⚠️ Sick leave is limited to 1 day per request</span>
              )}
            </p>
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Reason for Leave *</label>
          <textarea
            value={newRequest.reason}
            onChange={(e) => setNewRequest({...newRequest, reason: e.target.value})}
            rows={3}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Please provide a brief reason for your leave request"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Coverage Arranged With</label>
          <select
            value={newRequest.coverageBy}
            onChange={(e) => setNewRequest({...newRequest, coverageBy: e.target.value})}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select Coverage Person</option>
            {teammates.map(teammate => (
              <option key={teammate.id} value={teammate.name}>{teammate.name}</option>
            ))}
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Emergency Contact</label>
          <input
            type="text"
            value={newRequest.emergencyContact}
            onChange={(e) => setNewRequest({...newRequest, emergencyContact: e.target.value})}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Emergency contact number during leave"
          />
        </div>

        {newRequest.type === 'Sick Leave' && (
          <div className="flex items-center">
            <input
              type="checkbox"
              id="medicalCert"
              checked={newRequest.medicalCertificate}
              onChange={(e) => setNewRequest({...newRequest, medicalCertificate: e.target.checked})}
              className="mr-2"
            />
            <label htmlFor="medicalCert" className="text-sm text-gray-700">
              I will provide a medical certificate if required
            </label>
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Additional Notes</label>
          <textarea
            value={newRequest.additionalNotes}
            onChange={(e) => setNewRequest({...newRequest, additionalNotes: e.target.value})}
            rows={2}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            placeholder="Any additional information"
          />
        </div>

        <div className="bg-yellow-50 p-4 rounded-md border border-yellow-200">
          <h4 className="font-medium text-yellow-800 mb-2">Important Reminders:</h4>
          <ul className="text-sm text-yellow-700 space-y-1">
            <li>• Submit requests at least 2 weeks in advance for planned leave</li>
            <li>• Ensure coverage is arranged before submitting</li>
            <li>• Emergency leave can be submitted with 24-hour notice</li>
            <li>• Sick leave is limited to 1 day per request</li>
            <li>• Medical certificates required for sick leave documentation</li>
          </ul>
        </div>

        <div className="flex justify-end space-x-3 pt-4">
          <button
            onClick={() => setShowRequestForm(false)}
            className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmitRequest}
            className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
          >
            Submit Request
          </button>
        </div>
      </div>
    </div>
  );

  const renderMyRequests = () => (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold">My Leave Requests</h2>
        <button
          onClick={() => setShowRequestForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
        >
          <Send className="h-4 w-4" />
          New Request
        </button>
      </div>

      {showRequestForm && renderRequestForm()}

      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Dates</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Days</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Coverage</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Submitted</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {myRequests.length === 0 ? (
                <tr>
                  <td colSpan="6" className="px-6 py-4 text-center text-gray-500">
                    No requests submitted yet
                  </td>
                </tr>
              ) : (
                myRequests.map((request) => (
                  <tr key={request.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{request.type}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {request.start_date} {request.start_date !== request.end_date ? `to ${request.end_date}` : ''}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{request.days}</td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(request.status)}`}>
                        {request.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {request.coverage_by || 'Not arranged'}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{request.submit_date}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const renderLeavePolicy = () => (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">Leave Policy & Guidelines</h2>
      {policyLoading ? (
        <div>Loading...</div>
      ) : policyError ? (
        <div className="text-red-600">{policyError}</div>
      ) : policy ? (
        <div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
            <div className="bg-white rounded-lg shadow-sm border p-6">
              <h3 className="text-lg font-semibold mb-4 text-blue-800">Leave Types</h3>
              <div className="space-y-2">
                {policy.leaveTypes?.map((type, index) => (
                  <div key={index} className="flex justify-between text-sm">
                    <span>{type.label}:</span>
                    <span className="font-medium">{type.maxDays} days ({type.paid ? 'Paid' : 'Unpaid'})</span>
                  </div>
                ))}
              </div>
            </div>
            
            <div className="bg-white rounded-lg shadow-sm border p-6">
              <h3 className="text-lg font-semibold mb-4 text-green-800">Your Entitlements</h3>
              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span>Annual Leave:</span>
                  <span className="font-medium">{policy.entitlements?.annualLeave || 15} days per year</span>
                </div>
                <div className="flex justify-between">
                  <span>Sick Leave:</span>
                  <span className="font-medium">{policy.entitlements?.sickLeave || 10} days per year</span>
                </div>
              </div>
            </div>
          </div>
          
          <div className="bg-white rounded-lg shadow-sm border p-6 mb-6">
            <h3 className="text-lg font-semibold mb-4">Guidelines</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-medium mb-3 text-gray-800">Request Procedures</h4>
                <ul className="space-y-2 text-sm text-gray-600">
                  {policy.guidelines?.requestProcedures?.map((procedure, index) => (
                    <li key={index}>• {procedure}</li>
                  ))}
                </ul>
              </div>
              <div>
                <h4 className="font-medium mb-3 text-gray-800">Coverage Requirements</h4>
                <ul className="space-y-2 text-sm text-gray-600">
                  {policy.guidelines?.coverageRequirements?.map((requirement, index) => (
                    <li key={index}>• {requirement}</li>
                  ))}
                </ul>
              </div>
            </div>
          </div>
        </div>
      ) : (
        <div>No policy found.</div>
      )}
    </div>
  );

  useEffect(() => {
    async function fetchPolicy() {
      setPolicyLoading(true);
      try {
        const res = await dataService.getCurrentPolicy();
        setPolicy(res?.content || null);
      } catch (e) {
        setPolicyError('Failed to load policy');
      } finally {
        setPolicyLoading(false);
      }
    }
    fetchPolicy();
  }, []);

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Employee Portal</h1>
              <p className="text-sm text-gray-600">Leave Request & Management System</p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="text-sm text-gray-600">
                <Clock className="inline h-4 w-4 mr-1" />
                Shift: 5:00 PM - 1:00 AM
              </div>
              <button
                onClick={handleLogout}
                className="flex items-center px-3 py-2 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-md"
              >
                <LogOut className="h-4 w-4 mr-1" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="flex space-x-1 mb-6">
          {[
            { id: 'overview', label: 'Overview', icon: Calendar },
            { id: 'requests', label: 'My Requests', icon: FileText },
            { id: 'policy', label: 'Leave Policy', icon: FileText }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center px-4 py-2 rounded-lg text-sm font-medium ${
                activeTab === tab.id
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <tab.icon className="h-4 w-4 mr-2" />
              {tab.label}
            </button>
          ))}
        </div>

        <div>
          {activeTab === 'overview' && renderOverview()}
          {activeTab === 'requests' && renderMyRequests()}
          {activeTab === 'policy' && renderLeavePolicy()}
        </div>
      </div>
    </div>
  );
};

export default EmployeePortal; 