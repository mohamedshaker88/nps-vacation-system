import React, { useState, useEffect } from 'react';
import { Calendar, Clock, User, Send, CheckCircle, XCircle, AlertCircle, FileText, Phone, Mail, LogOut, Eye, EyeOff, Bell } from 'lucide-react';
import { dataService } from '../services/dataService';

const EmployeePortal = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentEmployee, setCurrentEmployee] = useState(null);
  const [showLogin, setShowLogin] = useState(true);
  const [showRegister, setShowRegister] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [employeeDataLoading, setEmployeeDataLoading] = useState(false);
  
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
    medicalCertificate: false,
    exchangeDate: '',
    exchangePartnerId: '',
    exchangeReason: '',
    partnerDesiredOffDate: ''
  });

  const [availableCoverage, setAvailableCoverage] = useState([]);

  const [showRequestForm, setShowRequestForm] = useState(false);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifications, setShowNotifications] = useState(false);
  const [pendingExchangeApprovals, setPendingExchangeApprovals] = useState([]);

  // Load available coverage for exchange requests
  const loadAvailableCoverage = async (date) => {
    if (!date) {
      setAvailableCoverage([]);
      return;
    }

    try {
      const coverage = await dataService.getAvailableCoverage(date);
      setAvailableCoverage(coverage);
    } catch (error) {
      console.error('Error loading available coverage:', error);
      setAvailableCoverage([]);
    }
  };
  const [activeTab, setActiveTab] = useState('overview');

  const [policy, setPolicy] = useState(null);
  const [policyLoading, setPolicyLoading] = useState(false);
  const [policyError, setPolicyError] = useState('');

  const leaveTypes = [
    { value: 'Annual Leave', label: 'Annual Leave', maxDays: 14, paid: true, description: 'Paid vacation time' },
    { value: 'Sick Leave', label: 'Sick Leave', maxDays: 1, paid: true, description: 'Paid sick day (1 day maximum per request)' },
    { value: 'Exchange Off Days', label: 'Exchange Off Days', maxDays: 1, paid: false, description: 'Exchange scheduled off days with other days', isExchange: true }
  ];

  // Load data from Supabase
  useEffect(() => {
    const savedAuth = localStorage.getItem('employeeAuth');
    const savedEmployee = localStorage.getItem('currentEmployee');
    
    if (savedAuth === 'true' && savedEmployee) {
      const employee = JSON.parse(savedEmployee);
      setIsAuthenticated(true);
      setEmployeeDataLoading(true);
      // Refresh employee data from database to get latest vacation balances
      refreshEmployeeData(employee.email);
    }
  }, []);

  // Fetch policy data
  useEffect(() => {
    async function fetchPolicy() {
      setPolicyLoading(true);
      try {
        console.log('Fetching policy...');
        const res = await dataService.getCurrentPolicy();
        console.log('Policy response:', res);
        
        if (res && res.content) {
          setPolicy(res.content);
        } else {
          // No policy found, use default
          console.log('No policy found, using default');
          setPolicy({
            leaveTypes: leaveTypes,
            entitlements: { annualLeave: 15, sickLeave: 10 },
            guidelines: {
              requestProcedures: [
                "Submit requests at least 2 weeks in advance for planned leave",
                "Emergency leave can be requested with 24-hour notice",
                "All requests must include coverage arrangements"
              ],
              coverageRequirements: [
                "24/7 coverage must be maintained (5pm-1am daily)",
                "Minimum 8 staff members must be available",
                "Cross-training required for all team members"
              ]
            }
          });
        }
      } catch (e) {
        console.error('Error fetching policy:', e);
        setPolicyError('Failed to load policy');
        // Set a default policy to prevent white page
        setPolicy({
          leaveTypes: leaveTypes,
          entitlements: { annualLeave: 15, sickLeave: 10 },
          guidelines: {
            requestProcedures: [
              "Submit requests at least 2 weeks in advance for planned leave",
              "Emergency leave can be requested with 24-hour notice",
              "All requests must include coverage arrangements"
            ],
            coverageRequirements: [
              "24/7 coverage must be maintained (5pm-1am daily)",
              "Minimum 8 staff members must be available",
              "Cross-training required for all team members"
            ]
          }
        });
      } finally {
        setPolicyLoading(false);
      }
    }
    fetchPolicy();
  }, []);

  // Load available coverage when exchange request date changes
  useEffect(() => {
    if (newRequest.type === 'Exchange Off Days' && newRequest.startDate) {
      loadAvailableCoverage(newRequest.startDate);
    }
  }, [newRequest.type, newRequest.startDate]);

  const refreshEmployeeData = async (email) => {
    try {
      setEmployeeDataLoading(true);
      console.log('=== REFRESHING EMPLOYEE DATA ===');
      console.log('Looking up employee by email:', email);
      
      // Get fresh employee data from database
      const freshEmployee = await dataService.getEmployeeByEmail(email);
      console.log('Fresh employee data:', freshEmployee);
      
      if (freshEmployee) {
        setCurrentEmployee(freshEmployee);
        console.log('Calling loadEmployeeData for fresh employee:', freshEmployee);
        await loadEmployeeData(freshEmployee);
      } else {
        console.error('No employee found for email:', email);
        // Fallback to localStorage data if database fetch fails
        const savedEmployee = localStorage.getItem('currentEmployee');
        if (savedEmployee) {
          const employee = JSON.parse(savedEmployee);
          console.log('Using saved employee data:', employee);
          setCurrentEmployee(employee);
          await loadEmployeeData(employee);
        }
      }
    } catch (error) {
      console.error('Error refreshing employee data:', error);
      console.error('Error details:', error.message, error.stack);
      // Fallback to localStorage data if refresh fails
      const savedEmployee = localStorage.getItem('currentEmployee');
      if (savedEmployee) {
        const employee = JSON.parse(savedEmployee);
        console.log('Using saved employee data after error:', employee);
        setCurrentEmployee(employee);
        await loadEmployeeData(employee);
      }
    } finally {
      setEmployeeDataLoading(false);
    }
  };

  const loadEmployeeData = async (employee) => {
    try {
      setLoading(true);
      console.log('=== LOADING EMPLOYEE DATA ===');
      console.log('Employee object:', employee);
      console.log('Employee ID:', employee.id);
      console.log('Employee Name:', employee.name);
      console.log('Employee Email:', employee.email);
      
      // Load requests for this employee
      const employeeRequests = await dataService.getRequestsByEmployee(employee.email);
      setMyRequests(employeeRequests);
      console.log('Employee requests loaded:', employeeRequests);

      // Load all employees for coverage selection
      const allEmployees = await dataService.getEmployees();
      const otherEmployees = allEmployees.filter(emp => emp.email !== employee.email);
      setTeammates(otherEmployees);
      console.log('Teammates loaded:', otherEmployees.length);

      // Load notifications
      console.log('Loading notifications for employee ID:', employee.id);
      const employeeNotifications = await dataService.getNotifications(employee.id);
      console.log('Notifications loaded:', employeeNotifications);
      setNotifications(employeeNotifications);
      
      // Load unread count
      console.log('Loading unread count for employee ID:', employee.id);
      const unreadNotifications = await dataService.getUnreadNotificationCount(employee.id);
      console.log('Unread count loaded:', unreadNotifications);
      setUnreadCount(unreadNotifications);
      
      // Load pending exchange approvals
      console.log('Loading pending approvals for employee ID:', employee.id, 'Name:', employee.name);
      const pendingApprovals = await dataService.getPendingExchangeApprovals(employee.id);
      console.log('Pending approvals loaded:', pendingApprovals);
      console.log('Pending approvals count:', pendingApprovals ? pendingApprovals.length : 0);
      setPendingExchangeApprovals(pendingApprovals);
      
      console.log('=== EMPLOYEE DATA LOADING COMPLETE ===');
    } catch (error) {
      console.error('Error loading employee data:', error);
      console.error('Error details:', error.message, error.stack);
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
      setIsAuthenticated(true);
      localStorage.setItem('employeeAuth', 'true');
      localStorage.setItem('currentEmployee', JSON.stringify(newEmployee));
      
      // Refresh employee data to get latest vacation balances
      refreshEmployeeData(newEmployee.email);
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
      console.log('=== LOGIN SUCCESSFUL ===');
      console.log('Authenticated employee:', employee);
      setIsAuthenticated(true);
      localStorage.setItem('employeeAuth', 'true');
      localStorage.setItem('currentEmployee', JSON.stringify(employee));
      
      // Refresh employee data to get latest vacation balances
      console.log('Calling refreshEmployeeData for:', employee.email);
      refreshEmployeeData(employee.email);
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
    if (!newRequest.type || !newRequest.startDate || !newRequest.endDate || !newRequest.reason || !newRequest.exchangePartnerId) {
      alert('Please fill in all required fields including the coverage partner');
      return;
    }

    const selectedLeaveType = leaveTypes.find(type => type.value === newRequest.type);
    const days = calculateDays(newRequest.startDate, newRequest.endDate);

    // Validate that exchange partner is selected for all leave types
    if (!newRequest.exchangePartnerId) {
      alert('Please select a coverage partner for your leave request');
      return;
    }

    // Additional validation for exchange requests
    if (newRequest.type === 'Exchange Off Days') {
      if (!newRequest.exchangeReason) {
        alert('Please provide a reason for the exchange request');
        return;
      }

      if (!newRequest.partnerDesiredOffDate) {
        alert('Please select the date your exchange partner wants off');
        return;
      }

      // Validate that exchange is exactly 1 day
      if (days !== 1) {
        alert('Exchange Off Days requests must be exactly 1 day');
        return;
      }

      // Validate that the two dates are different
      if (newRequest.startDate === newRequest.partnerDesiredOffDate) {
        alert('You cannot exchange the same date. Please select different dates for you and your partner.');
        return;
      }

      // Validate that the exchange partner has an off day on the requested date
      if (newRequest.exchangePartnerId) {
        try {
          const exchangePartner = teammates.find(emp => emp.id === parseInt(newRequest.exchangePartnerId));
          if (exchangePartner) {
            const dayStatus = await dataService.getEmployeeDayStatus(exchangePartner.id, newRequest.startDate);
            if (dayStatus !== 'off') {
              alert(`The selected exchange partner (${exchangePartner.name}) is scheduled to work on ${newRequest.startDate}. Please select someone who has an off day on that date.`);
              return;
            }
          }
        } catch (error) {
          console.error('Error checking exchange partner availability:', error);
          alert('Error validating exchange partner availability. Please try again.');
          return;
        }
      }
    }
    
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
      coverage_by: newRequest.coverageBy || null,
      emergency_contact: newRequest.emergencyContact || null,
      additional_notes: newRequest.additionalNotes || null,
      medical_certificate: newRequest.medicalCertificate || false,
      exchange_from_date: newRequest.startDate,
      exchange_to_date: newRequest.endDate,
      exchange_reason: newRequest.exchangeReason || newRequest.reason,
      exchange_partner_id: newRequest.exchangePartnerId ? parseInt(newRequest.exchangePartnerId) : null,
      partner_desired_off_date: newRequest.partnerDesiredOffDate || null,
      requires_partner_approval: newRequest.exchangePartnerId ? true : false
    };

    try {
      console.log('Submitting request:', request);
      
      // Save to Supabase
      const newRequestData = await dataService.saveRequest(request);
      console.log('Request saved successfully:', newRequestData);
      
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
        medicalCertificate: false,
        exchangeDate: '',
        exchangePartnerId: '',
        exchangeReason: '',
        partnerDesiredOffDate: ''
      });
      setShowRequestForm(false);
      alert('Leave request submitted successfully!');
    } catch (error) {
      console.error('Error submitting request:', error);
      console.error('Error details:', {
        message: error.message,
        code: error.code,
        details: error.details,
        hint: error.hint
      });
      alert(`Error submitting request: ${error.message || 'Please try again.'}`);
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

  const handleExchangeApproval = async (requestId, approved, notes = '') => {
    try {
      await dataService.approveExchangeRequest(requestId, currentEmployee.id, approved, notes);
      
      // Remove from pending approvals
      setPendingExchangeApprovals(pendingExchangeApprovals.filter(approval => approval.request_id !== requestId));
      
      // Refresh notifications
      const employeeNotifications = await dataService.getNotifications(currentEmployee.id);
      setNotifications(employeeNotifications);
      
      const unreadNotifications = await dataService.getUnreadNotificationCount(currentEmployee.id);
      setUnreadCount(unreadNotifications);
      
      alert(`Exchange request ${approved ? 'approved' : 'rejected'} successfully!`);
    } catch (error) {
      console.error('Error approving exchange request:', error);
      alert(`Error ${approved ? 'approving' : 'rejecting'} exchange request: ${error.message}`);
    }
  };

  // Use individual employee entitlements if available, otherwise fall back to policy defaults
  const annualLeaveEntitlement = currentEmployee?.annual_leave_total || policy?.entitlements?.annualLeave || 15;
  const sickLeaveEntitlement = currentEmployee?.sick_leave_total || policy?.entitlements?.sickLeave || 10;

  // Calculate leave balances using dynamic policy
  // Use individual employee remaining balances if available, otherwise calculate from requests
  const usedAnnual = myRequests.filter(r => 
    r.type === 'Annual Leave' && r.status === 'Approved'
  ).reduce((sum, r) => sum + r.days, 0);
  
  const usedSick = myRequests.filter(r => 
    r.type === 'Sick Leave' && r.status === 'Approved'
  ).reduce((sum, r) => sum + r.days, 0);

  // Use individual employee remaining balances if available
  const annualRemaining = currentEmployee?.annual_leave_remaining !== undefined 
    ? currentEmployee.annual_leave_remaining 
    : (annualLeaveEntitlement - usedAnnual);
    
  const sickRemaining = currentEmployee?.sick_leave_remaining !== undefined 
    ? currentEmployee.sick_leave_remaining 
    : (sickLeaveEntitlement - usedSick);

  // Override policy leave types with simplified list for employees
  const dynamicLeaveTypes = leaveTypes;

  // Show loading state if authenticated but employee data is still loading
  if (isAuthenticated && employeeDataLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-4 text-gray-600">Loading your account...</p>
        </div>
      </div>
    );
  }

  // Show error state if authenticated but no employee data
  if (isAuthenticated && !currentEmployee) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-600 mb-4">Unable to load your account data</p>
          <button
            onClick={handleLogout}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
          >
            Logout and try again
          </button>
        </div>
      </div>
    );
  }

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
    <div className="space-y-4 sm:space-y-6">
      {(loading || employeeDataLoading) && (
        <div className="text-center py-8">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-2 text-gray-600">Loading your vacation data...</p>
        </div>
      )}
      
      <div className="bg-white rounded-lg shadow-sm border p-4 sm:p-6">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
          <div className="flex items-center space-x-3">
            <div className="bg-blue-100 p-2 sm:p-3 rounded-full">
              <User className="h-5 w-5 sm:h-6 sm:w-6 text-blue-600" />
            </div>
            <div>
              <h2 className="text-lg sm:text-xl font-semibold">Welcome, {currentEmployee.name}</h2>
              <p className="text-sm sm:text-base text-gray-600">{currentEmployee.email}</p>
            </div>
          </div>
          <div className="text-left sm:text-right">
            <p className="text-sm text-gray-600">{currentEmployee.phone}</p>
            <p className="text-sm text-gray-600">technetworkinc.com</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
        <div className="bg-blue-50 p-4 sm:p-6 rounded-lg border border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-600 text-sm font-medium">Annual Leave</p>
              <p className="text-xl sm:text-2xl font-bold text-blue-800">
                {annualRemaining}/{annualLeaveEntitlement}
              </p>
              <p className="text-xs text-blue-600">Days Remaining</p>
            </div>
            <Calendar className="h-6 w-6 sm:h-8 sm:w-8 text-blue-600" />
          </div>
          <div className="mt-3 w-full bg-blue-200 rounded-full h-2">
            <div 
              className="bg-blue-600 h-2 rounded-full" 
              style={{width: `${((annualLeaveEntitlement - annualRemaining) / annualLeaveEntitlement) * 100}%`}}
            ></div>
          </div>
        </div>

        <div className="bg-green-50 p-4 sm:p-6 rounded-lg border border-green-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-600 text-sm font-medium">Sick Leave</p>
              <p className="text-xl sm:text-2xl font-bold text-green-800">
                {sickRemaining}/{sickLeaveEntitlement}
              </p>
              <p className="text-xs text-green-600">Days Remaining</p>
            </div>
            <FileText className="h-6 w-6 sm:h-8 sm:w-8 text-green-600" />
          </div>
          <div className="mt-3 w-full bg-green-200 rounded-full h-2">
            <div 
              className="bg-green-600 h-2 rounded-full" 
              style={{width: `${((sickLeaveEntitlement - sickRemaining) / sickLeaveEntitlement) * 100}%`}}
            ></div>
          </div>
        </div>

        <div className="bg-purple-50 p-4 sm:p-6 rounded-lg border border-purple-200 sm:col-span-2 lg:col-span-1">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-purple-600 text-sm font-medium">Pending Requests</p>
              <p className="text-xl sm:text-2xl font-bold text-purple-800">
                {myRequests.filter(r => r.status === 'Pending').length}
              </p>
              <p className="text-xs text-purple-600">Awaiting Approval</p>
            </div>
            <Clock className="h-6 w-6 sm:h-8 sm:w-8 text-purple-600" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border">
        <div className="p-4 border-b flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
          <h3 className="text-lg font-semibold">Recent Requests</h3>
          <button
            onClick={() => setShowRequestForm(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center justify-center gap-2 text-sm sm:text-base"
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
              <div key={request.id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between py-3 border-b last:border-b-0 gap-2">
                <div>
                  <div className="font-medium text-sm sm:text-base">{request.type}</div>
                  <div className="text-xs sm:text-sm text-gray-600">
                    {request.start_date} {request.start_date !== request.end_date ? `to ${request.end_date}` : ''} • {request.days} day{request.days > 1 ? 's' : ''}
                  </div>
                </div>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(request.status)} self-start sm:self-auto`}>
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

        {/* Date inputs - single date for Sick Leave and Exchange Off Days */}
        {(newRequest.type === 'Sick Leave' || newRequest.type === 'Exchange Off Days') ? (
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Date *</label>
            <input
              type="date"
              value={newRequest.startDate}
              onChange={(e) => {
                setNewRequest({
                  ...newRequest, 
                  startDate: e.target.value,
                  endDate: e.target.value // Set end date same as start date for single day
                });
              }}
              min={new Date().toISOString().split('T')[0]}
              className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
        ) : (
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
        )}

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

        {/* Exchange Partner Selection - Required for all leave types */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            {newRequest.type === 'Exchange Off Days' ? 'Exchange Partner *' : 'Coverage Partner *'}
          </label>
          <select
            value={newRequest.exchangePartnerId}
            onChange={(e) => setNewRequest({...newRequest, exchangePartnerId: e.target.value})}
            className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <option value="">Select {newRequest.type === 'Exchange Off Days' ? 'Exchange' : 'Coverage'} Partner</option>
            {teammates.map(teammate => (
              <option key={teammate.id} value={teammate.id}>{teammate.name} ({teammate.email})</option>
            ))}
          </select>
        </div>

        {/* Exchange-specific fields for Exchange Off Days */}
        {newRequest.type === 'Exchange Off Days' && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                When does your exchange partner want off? *
              </label>
              <input
                type="date"
                value={newRequest.partnerDesiredOffDate || ''}
                onChange={(e) => setNewRequest({...newRequest, partnerDesiredOffDate: e.target.value})}
                min={new Date().toISOString().split('T')[0]}
                className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Select the date your partner wants off"
              />
              <p className="text-xs text-gray-500 mt-1">
                This is the date you'll work to cover for your exchange partner
              </p>
            </div>
            
            <div className="bg-blue-50 p-4 rounded-md">
              <h4 className="font-medium text-blue-800 mb-2">📅 Exchange Summary</h4>
              {newRequest.startDate && newRequest.partnerDesiredOffDate ? (
                <div className="text-sm text-blue-700 space-y-1">
                  <div>• <strong>You get off:</strong> {newRequest.startDate}</div>
                  <div>• <strong>Partner gets off:</strong> {newRequest.partnerDesiredOffDate}</div>
                  <div>• <strong>You cover partner's shift:</strong> {newRequest.partnerDesiredOffDate}</div>
                  <div>• <strong>Partner covers your shift:</strong> {newRequest.startDate}</div>
                </div>
              ) : (
                <div className="text-sm text-blue-600">
                  Fill in both dates to see the exchange summary
                </div>
              )}
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Exchange Reason *</label>
              <textarea
                value={newRequest.exchangeReason}
                onChange={(e) => setNewRequest({...newRequest, exchangeReason: e.target.value})}
                rows={3}
                className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Please explain why you need to exchange these off days"
              />
            </div>
          </>
        )}

        {/* Show available coverage for exchange requests */}
        {newRequest.type === 'Exchange Off Days' && newRequest.startDate && (
          <div className="bg-blue-50 p-3 rounded-md">
            <p className="text-sm text-blue-800 mb-2">
              Available coverage for {newRequest.startDate}:
            </p>
            {availableCoverage.length > 0 ? (
              <div className="space-y-1">
                {availableCoverage
                  .filter(emp => emp.employee_id !== currentEmployee.id)
                  .map(emp => (
                    <div key={emp.employee_id} className="text-sm text-blue-700">
                      • {emp.employee_name} ({emp.employee_email})
                    </div>
                  ))
                }
              </div>
            ) : (
              <p className="text-sm text-blue-600">No employees available for coverage on this date</p>
            )}
          </div>
        )}

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
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Exchange Info</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Submitted</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {myRequests.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-4 text-center text-gray-500">
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
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {request.type === 'Exchange Off Days' && request.exchange_to_date ? (
                        <div>
                          <div className="text-xs font-medium text-blue-700">You get off: {request.exchange_to_date}</div>
                          {request.partner_desired_off_date && (
                            <div className="text-xs font-medium text-green-700">Partner gets off: {request.partner_desired_off_date}</div>
                          )}
                          {request.exchange_reason && (
                            <div className="text-xs text-gray-600 mt-1">{request.exchange_reason}</div>
                          )}
                          {!request.partner_desired_off_date && (
                            <div className="text-xs text-red-600 mt-1">⚠️ Missing partner's desired off date</div>
                          )}
                        </div>
                      ) : (
                        <span className="text-gray-400">-</span>
                      )}
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

  const renderPendingApprovals = () => (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold">Pending Exchange Approvals</h2>
        <div className="text-sm text-gray-600">
          {pendingExchangeApprovals.length} pending approval{pendingExchangeApprovals.length !== 1 ? 's' : ''}
        </div>
      </div>

      {pendingExchangeApprovals.length === 0 ? (
        <div className="bg-white rounded-lg shadow-sm border p-8 text-center">
          <CheckCircle className="h-12 w-12 text-green-500 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">No Pending Approvals</h3>
          <p className="text-gray-600">You have no exchange requests waiting for your approval.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {pendingExchangeApprovals.map((approval) => (
            <div key={approval.request_id} className="bg-white rounded-lg shadow-sm border p-6">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-medium text-gray-900">
                    Exchange Request from {approval.requester_name}
                  </h3>
                  <p className="text-sm text-gray-600">{approval.requester_email}</p>
                </div>
                <div className="text-xs text-gray-500">
                  {new Date(approval.request_created_at).toLocaleDateString()}
                </div>
              </div>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <div>
                  <h4 className="font-medium text-sm text-gray-700 mb-1">Exchange Details</h4>
                  <div className="text-sm text-gray-600">
                    <div>From: {approval.exchange_from_date}</div>
                    <div>To: {approval.exchange_to_date}</div>
                  </div>
                </div>
                <div>
                  <h4 className="font-medium text-sm text-gray-700 mb-1">Reason</h4>
                  <p className="text-sm text-gray-600">{approval.exchange_reason || 'No reason provided'}</p>
                </div>
              </div>
              
              <div className="flex gap-2">
                <button
                  onClick={() => handleExchangeApproval(approval.request_id, true)}
                  className="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 flex items-center justify-center gap-2"
                >
                  <CheckCircle className="h-4 w-4" />
                  Approve
                </button>
                <button
                  onClick={() => {
                    const notes = prompt('Please provide a reason for rejection (optional):');
                    if (notes !== null) {
                      handleExchangeApproval(approval.request_id, false, notes);
                    }
                  }}
                  className="flex-1 bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 flex items-center justify-center gap-2"
                >
                  <XCircle className="h-4 w-4" />
                  Reject
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
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

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-4 gap-4">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-gray-900">Employee Portal</h1>
              <p className="text-xs sm:text-sm text-gray-600">Leave Request & Management System</p>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
              <div className="text-xs sm:text-sm text-gray-600">
                <Clock className="inline h-3 w-3 sm:h-4 sm:w-4 mr-1" />
                Shift: 5:00 PM - 1:00 AM
              </div>
              
              {/* Notification Bell */}
              <div className="relative">
                <button
                  onClick={() => setShowNotifications(!showNotifications)}
                  className="flex items-center justify-center px-3 py-2 text-xs sm:text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-md relative"
                >
                  <Bell className="h-3 w-3 sm:h-4 sm:w-4 mr-1" />
                  {unreadCount > 0 && (
                    <span className="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full h-4 w-4 flex items-center justify-center">
                      {unreadCount}
                    </span>
                  )}
                </button>
                
                {/* Notification Dropdown */}
                {showNotifications && (
                  <div className="absolute right-0 mt-2 w-80 bg-white rounded-md shadow-lg border z-50 max-h-96 overflow-y-auto">
                    <div className="p-4 border-b">
                      <h3 className="font-semibold text-sm">Notifications</h3>
                    </div>
                    {notifications.length === 0 ? (
                      <div className="p-4 text-gray-500 text-center text-sm">
                        No notifications
                      </div>
                    ) : (
                      <div className="divide-y">
                        {notifications.map((notification) => (
                          <div 
                            key={notification.id} 
                            className={`p-4 hover:bg-gray-50 cursor-pointer ${!notification.is_read ? 'bg-blue-50' : ''}`}
                            onClick={async () => {
                              if (!notification.is_read) {
                                await dataService.markNotificationAsRead(notification.id);
                                setNotifications(notifications.map(n => 
                                  n.id === notification.id ? { ...n, is_read: true } : n
                                ));
                                setUnreadCount(Math.max(0, unreadCount - 1));
                              }
                            }}
                          >
                            <div className="flex items-start justify-between">
                              <div className="flex-1">
                                <h4 className="font-medium text-sm">{notification.title}</h4>
                                <p className="text-sm text-gray-600 mt-1">{notification.message}</p>
                                <p className="text-xs text-gray-400 mt-2">
                                  {new Date(notification.created_at).toLocaleString()}
                                </p>
                              </div>
                              {!notification.is_read && (
                                <div className="w-2 h-2 bg-blue-500 rounded-full ml-2"></div>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </div>
              
              <button
                onClick={handleLogout}
                className="flex items-center justify-center px-3 py-2 text-xs sm:text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-md"
              >
                <LogOut className="h-3 w-3 sm:h-4 sm:w-4 mr-1" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        <div className="flex flex-wrap gap-1 sm:gap-2 mb-4 sm:mb-6">
          {[
            { id: 'overview', label: 'Overview', icon: Calendar },
            { id: 'requests', label: 'My Requests', icon: FileText },
            { id: 'approvals', label: `Pending Approvals ${pendingExchangeApprovals.length > 0 ? `(${pendingExchangeApprovals.length})` : ''}`, icon: CheckCircle },
            { id: 'policy', label: 'Leave Policy', icon: FileText }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`flex items-center px-3 sm:px-4 py-2 rounded-lg text-xs sm:text-sm font-medium ${
                activeTab === tab.id
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
              }`}
            >
              <tab.icon className="h-3 w-3 sm:h-4 sm:w-4 mr-1 sm:mr-2" />
              {tab.label}
            </button>
          ))}
        </div>

        <div>
          {activeTab === 'overview' && renderOverview()}
          {activeTab === 'requests' && renderMyRequests()}
          {activeTab === 'approvals' && renderPendingApprovals()}
          {activeTab === 'policy' && renderLeavePolicy()}
        </div>
      </div>
    </div>
  );
};

export default EmployeePortal; 