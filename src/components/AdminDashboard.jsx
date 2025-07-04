import React, { useState, useEffect } from 'react';
import { Calendar, Users, Clock, CheckCircle, XCircle, AlertCircle, Plus, Edit, Trash2, User, Mail, Phone, MapPin, FileText, Download, LogOut, Eye, EyeOff, Save, X, RefreshCw, Copy } from 'lucide-react';
import { dataService } from '../services/dataService';
import WorkScheduleManager from './WorkScheduleManager';
import WorkScheduleTemplateManager from './WorkScheduleTemplateManager';

const AdminDashboard = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loginForm, setLoginForm] = useState({ username: '', password: '' });
  const [loginError, setLoginError] = useState('');
  const [activeTab, setActiveTab] = useState('dashboard');
  const [loading, setLoading] = useState(false);
  const [hasError, setHasError] = useState(false);

  // Load employees and requests from Supabase
  const [employees, setEmployees] = useState([]);
  const [requests, setRequests] = useState([]);

  const [newRequest, setNewRequest] = useState({
    employeeId: '',
    type: '',
    startDate: '',
    endDate: '',
    reason: '',
    coverageBy: '',
    medicalCertificate: false,
    emergencyContact: '',
    additionalNotes: '',
    exchangeDate: '',
    exchangePartnerId: '',
    exchangeReason: '',
    partnerDesiredOffDate: ''
  });

  const [availableCoverage, setAvailableCoverage] = useState([]);

  const [showRequestForm, setShowRequestForm] = useState(false);

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

  // Employee management states
  const [showEmployeeForm, setShowEmployeeForm] = useState(false);
  const [editingEmployee, setEditingEmployee] = useState(null);
  const [editingVacation, setEditingVacation] = useState(null);
  const [newEmployee, setNewEmployee] = useState({
    name: '',
    email: '',
    phone: '',
    password: '',
    annual_leave_remaining: 15,
    sick_leave_remaining: 10
  });

  // Load data from Supabase
  const loadData = async () => {
    try {
      setLoading(true);
      setHasError(false);
      console.log('Loading admin data...');
      
      // Load employees first
      let employeesData = [];
      try {
        employeesData = await dataService.getEmployees();
        console.log('Employees data:', employeesData);
      } catch (empError) {
        console.error('Error loading employees:', empError);
        employeesData = [];
      }
      
      // Load requests second
      let requestsData = [];
      try {
        requestsData = await dataService.getRequests();
        console.log('Requests data:', requestsData);
      } catch (reqError) {
        console.error('Error loading requests:', reqError);
        requestsData = [];
      }
      
      setEmployees(employeesData || []);
      setRequests(requestsData || []);
    } catch (error) {
      console.error('Error loading admin data:', error);
      setHasError(true);
      // Set empty arrays to prevent white page
      setEmployees([]);
      setRequests([]);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated) {
      loadData();
    }
  }, [isAuthenticated]);

  // Load available coverage when exchange request date changes
  useEffect(() => {
    if (newRequest.type === 'Exchange Off Days' && newRequest.startDate) {
      loadAvailableCoverage(newRequest.startDate);
    }
  }, [newRequest.type, newRequest.startDate]);

  // Check if admin is already logged in
  useEffect(() => {
    const adminAuth = localStorage.getItem('adminAuth');
    if (adminAuth === 'true') {
      setIsAuthenticated(true);
    }
  }, []);

  const handleLogin = () => {
    if (loginForm.username === 'admin' && loginForm.password === 'NPSTEAM!') {
      setIsAuthenticated(true);
      localStorage.setItem('adminAuth', 'true');
      setLoginError('');
    } else {
      setLoginError('Invalid username or password');
    }
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
    localStorage.removeItem('adminAuth');
    setLoginForm({ username: '', password: '' });
  };

  // Employee management handlers
  const handleCreateEmployee = async () => {
    if (!newEmployee.name || !newEmployee.email || !newEmployee.password) {
      alert('Please fill in all required fields');
      return;
    }

    try {
      const createdEmployee = await dataService.saveEmployee(newEmployee);
      setEmployees([createdEmployee, ...employees]);
      setNewEmployee({
        name: '',
        email: '',
        phone: '',
        password: '',
        annual_leave_remaining: 15,
        sick_leave_remaining: 10
      });
      setShowEmployeeForm(false);
    } catch (error) {
      console.error('Error creating employee:', error);
      alert('Error creating employee. Please try again.');
    }
  };

  const handleEditEmployee = async () => {
    if (!editingEmployee.name || !editingEmployee.email) {
      alert('Please fill in all required fields');
      return;
    }

    try {
      await dataService.updateEmployee(editingEmployee.id, {
        name: editingEmployee.name,
        email: editingEmployee.email,
        phone: editingEmployee.phone
      });
      
      // Refresh employee data from database to ensure consistency
      const updatedEmployees = await dataService.getEmployees();
      setEmployees(updatedEmployees);
      
      setEditingEmployee(null);
      alert('Employee updated successfully!');
    } catch (error) {
      console.error('Error updating employee:', error);
      alert('Error updating employee. Please try again.');
    }
  };

  const handleDeleteEmployee = async (id) => {
    if (!confirm('Are you sure you want to delete this employee? This action cannot be undone.')) {
      return;
    }

    try {
      await dataService.deleteEmployee(id);
      setEmployees(employees.filter(emp => emp.id !== id));
    } catch (error) {
      console.error('Error deleting employee:', error);
      alert('Error deleting employee. Please try again.');
    }
  };

  const handleUpdateVacationBalance = async () => {
    if (!editingVacation) return;
    
    try {
      setLoading(true);
      console.log('Updating vacation balance for employee:', editingVacation.id);
      console.log('New values:', {
        annual_leave_remaining: editingVacation.annual_leave_remaining,
        sick_leave_remaining: editingVacation.sick_leave_remaining,
        annual_leave_total: editingVacation.annual_leave_total,
        sick_leave_total: editingVacation.sick_leave_total
      });
      
      await dataService.updateEmployeeVacationBalance(
        editingVacation.id,
        editingVacation.annual_leave_remaining,
        editingVacation.sick_leave_remaining,
        editingVacation.annual_leave_total,
        editingVacation.sick_leave_total
      );
      
      // Add a small delay to ensure database update is complete
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Refresh both employee and request data from database to ensure consistency
      const [updatedEmployees, updatedRequests] = await Promise.all([
        dataService.getEmployees(),
        dataService.getRequests()
      ]);
      
      const updatedEmployee = updatedEmployees.find(emp => emp.id === editingVacation.id);
      console.log('Updated employee data:', updatedEmployee);
      
      // Debug the calculation for this specific employee
      if (updatedEmployee) {
        const usedAnnual = updatedRequests.filter(r => 
          r.employee_email === updatedEmployee.email && 
          r.type === 'Annual Leave' && 
          r.status === 'Approved'
        ).reduce((sum, r) => sum + r.days, 0);
        
        const hasExplicitAnnualRemaining = updatedEmployee.annual_leave_remaining !== null && updatedEmployee.annual_leave_remaining !== undefined;
        const calculatedAnnualRemaining = hasExplicitAnnualRemaining 
          ? updatedEmployee.annual_leave_remaining 
          : (updatedEmployee.annual_leave_total || 15) - usedAnnual;
        
        console.log('Calculation debug:', {
          employeeEmail: updatedEmployee.email,
          annual_leave_remaining: updatedEmployee.annual_leave_remaining,
          annual_leave_total: updatedEmployee.annual_leave_total,
          usedAnnual,
          hasExplicitAnnualRemaining,
          calculatedAnnualRemaining
        });
      }
      
      setEmployees(updatedEmployees);
      setRequests(updatedRequests);
      
      setEditingVacation(null);
      alert('Vacation balance updated successfully!');
    } catch (error) {
      console.error('Error updating vacation balance:', error);
      alert('Error updating vacation balance. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const leaveTypes = [
    { value: 'Annual Leave', label: 'Annual Leave', requiresCoverage: true, maxDays: 14, paid: true },
    { value: 'Sick Leave', label: 'Sick Leave', requiresCoverage: true, maxDays: 1, paid: true },
    { value: 'Emergency Leave', label: 'Emergency Leave', requiresCoverage: true, maxDays: 3, paid: false },
    { value: 'Personal Leave', label: 'Personal Day', requiresCoverage: true, maxDays: 1, paid: false },
    { value: 'Maternity Leave', label: 'Maternity Leave', requiresCoverage: true, maxDays: 70, paid: false },
    { value: 'Paternity Leave', label: 'Paternity Leave', requiresCoverage: true, maxDays: 7, paid: false },
    { value: 'Bereavement Leave', label: 'Bereavement Leave', requiresCoverage: true, maxDays: 5, paid: false },
    { value: 'Religious Leave', label: 'Religious Leave', requiresCoverage: true, maxDays: 2, paid: false },
    { value: 'Compensatory Time', label: 'Comp Time', requiresCoverage: true, maxDays: 3, paid: false },
    { value: 'Unpaid Leave', label: 'Unpaid Leave', requiresCoverage: true, maxDays: 30, paid: false },
    { value: 'Exchange Off Days', label: 'Exchange Off Days', requiresCoverage: false, maxDays: 1, paid: false, isExchange: true }
  ];

  const calculateDays = (start, end) => {
    if (!start || !end) return 0;
    const startDate = new Date(start);
    const endDate = new Date(end);
    const diffTime = Math.abs(endDate - startDate);
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
  };

  const handleSubmitRequest = async () => {
    if (!newRequest.employeeId || !newRequest.type || !newRequest.startDate || !newRequest.endDate || !newRequest.exchangePartnerId) {
      alert('Please fill in all required fields including the coverage partner');
      return;
    }

    const employee = employees.find(emp => emp.id === parseInt(newRequest.employeeId));
    const days = calculateDays(newRequest.startDate, newRequest.endDate);

    // Validate that exchange partner is selected for all leave types
    if (!newRequest.exchangePartnerId) {
      alert('Please select a coverage partner for the leave request');
      return;
    }

    // Additional validation for exchange requests
    if (newRequest.type === 'Exchange Off Days') {
      if (!newRequest.exchangeReason) {
        alert('Please provide a reason for the exchange request');
        return;
      }

      if (!newRequest.partnerDesiredOffDate) {
        alert('Please select the date the exchange partner wants off');
        return;
      }

      // Validate that exchange is exactly 1 day
      if (days !== 1) {
        alert('Exchange Off Days requests must be exactly 1 day');
        return;
      }

      // Validate that the two dates are different
      if (newRequest.startDate === newRequest.partnerDesiredOffDate) {
        alert('Exchange dates must be different. Please select different dates for requester and partner.');
        return;
      }

      // Validate that the exchange partner has an off day on the requested date
      if (newRequest.exchangePartnerId) {
        try {
          const exchangePartner = employees.find(emp => emp.id === parseInt(newRequest.exchangePartnerId));
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
    
    const request = {
      employee_name: employee.name,
      employee_email: employee.email,
      type: newRequest.type,
      start_date: newRequest.startDate,
      end_date: newRequest.endDate,
      days: days,
      reason: newRequest.reason,
      status: 'Pending',
      submit_date: new Date().toISOString().split('T')[0],
      coverage_arranged: !!newRequest.exchangePartnerId,
      coverage_by: newRequest.coverageBy,
      medical_certificate: newRequest.medicalCertificate,
      emergency_contact: newRequest.emergencyContact,
      additional_notes: newRequest.additionalNotes,
      exchange_from_date: newRequest.startDate, // Use start date for all types
      exchange_to_date: newRequest.endDate, // Use end date for all types
      exchange_reason: newRequest.exchangeReason || newRequest.reason, // Use exchange reason or fallback to main reason
      exchange_partner_id: parseInt(newRequest.exchangePartnerId),
      partner_desired_off_date: newRequest.partnerDesiredOffDate, // NEW: Partner's desired off day
      requires_partner_approval: true // All requests now require partner approval
    };

    try {
      const newRequestData = await dataService.saveRequest(request);
      setRequests([newRequestData, ...requests]);
      setNewRequest({
        employeeId: '',
        type: '',
        startDate: '',
        endDate: '',
        reason: '',
        coverageBy: '',
        medicalCertificate: false,
        emergencyContact: '',
        additionalNotes: '',
        exchangeDate: '',
        exchangePartnerId: '',
        exchangeReason: '',
        partnerDesiredOffDate: ''
      });
      setShowRequestForm(false);
    } catch (error) {
      console.error('Error saving request:', error);
      alert('Error saving request. Please try again.');
    }
  };

  const updateRequestStatus = async (id, status) => {
    try {
      const request = requests.find(req => req.id === id);
      console.log('Updating request status:', { id, status, request });
      
      // Check if admin can approve this request
      if (request && status === 'Approved') {
        const approvalCheck = await dataService.canAdminApproveRequest(id);
        console.log('Approval check result:', approvalCheck);
        
        if (!approvalCheck.can_approve) {
          alert(`Cannot approve this request: ${approvalCheck.reason}`);
          return;
        }
      }
      
      console.log('Proceeding with status update...');
      await dataService.updateRequestStatus(id, status);
      
      // Update local state
      setRequests(requests.map(req => 
        req.id === id ? { ...req, status } : req
      ));
      
      // Reload data to get fresh state
      await loadData();
      
      // Show success message for exchange requests
      if (status === 'Approved' && request.exchange_partner_id) {
        alert('Exchange request approved! Work schedules have been updated automatically.');
      } else if (status === 'Approved') {
        alert('Request approved successfully!');
      } else if (status === 'Rejected') {
        alert('Request rejected.');
      }
    } catch (error) {
      console.error('Error updating request:', error);
      alert('Error updating request status. Please try again.');
    }
  };

  const getStatusColor = (status) => {
    switch (status) {
      case 'Approved': return 'text-green-600 bg-green-100';
      case 'Rejected': return 'text-red-600 bg-red-100';
      case 'Pending': return 'text-yellow-600 bg-yellow-100';
      case 'Partner Approved': return 'text-blue-600 bg-blue-100';
      default: return 'text-gray-600 bg-gray-100';
    }
  };

  // Missing functions for renderRequestForm
  const renderDateInputs = () => {

    // Single date for Sick Leave and Exchange Off Days
    if (newRequest.type === 'Sick Leave' || newRequest.type === 'Exchange Off Days') {
      return (
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
      );
    }

    // Date range for other leave types
    return (
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
    );
  };

  const renderPartnerInput = () => {
    return (
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Exchange Partner *</label>
        <select
          value={newRequest.exchangePartnerId}
          onChange={(e) => setNewRequest({...newRequest, exchangePartnerId: e.target.value})}
          className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">Select Exchange Partner</option>
          {employees
            .filter(emp => emp.id !== parseInt(newRequest.employeeId))
            .map(emp => (
              <option key={emp.id} value={emp.id}>
                {emp.name} ({emp.email})
              </option>
            ))
          }
        </select>
        <p className="text-xs text-gray-500 mt-1">
          Select the person who will cover your shift during your leave
        </p>
      </div>
    );
  };

  const renderExchangeReason = () => {
    if (newRequest.type !== 'Exchange Off Days') {
      return null;
    }

    return (
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">Exchange Reason *</label>
        <textarea
          value={newRequest.exchangeReason}
          onChange={(e) => setNewRequest({...newRequest, exchangeReason: e.target.value})}
          rows={3}
          className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="Please provide a reason for the exchange request"
        />
      </div>
    );
  };

  const getDashboardStats = () => {
    const pending = requests.filter(r => r.status === 'Pending').length;
    const approved = requests.filter(r => r.status === 'Approved').length;
    const totalRequests = requests.length;
    const coverageNeeded = requests.filter(r => r.status === 'Approved' && !r.coverage_arranged).length;
    
    return { pending, approved, totalRequests, coverageNeeded };
  };

  const stats = getDashboardStats();

  const [policy, setPolicy] = useState(null);
  const [policyDraft, setPolicyDraft] = useState(null);
  const [editingPolicy, setEditingPolicy] = useState(false);
  const [policyLoading, setPolicyLoading] = useState(false);
  const [policyError, setPolicyError] = useState('');

  useEffect(() => {
    async function fetchPolicy() {
      setPolicyLoading(true);
      try {
        const res = await dataService.getCurrentPolicy();
        setPolicy(res?.content || null);
        setPolicyDraft(res?.content || null);
      } catch (e) {
        setPolicyError('Failed to load policy');
      } finally {
        setPolicyLoading(false);
      }
    }
    fetchPolicy();
  }, []);

  const handlePolicyEdit = () => {
    setEditingPolicy(true);
  };

  const handlePolicyCancel = () => {
    setPolicyDraft(policy);
    setEditingPolicy(false);
  };

  const handlePolicySave = async () => {
    setPolicyLoading(true);
    setPolicyError('');
    
    // Check if entitlements are being changed
    const entitlementsChanged = policy && policyDraft && 
      (policy.entitlements?.annualLeave !== policyDraft.entitlements?.annualLeave ||
       policy.entitlements?.sickLeave !== policyDraft.entitlements?.sickLeave);
    
    if (entitlementsChanged) {
      const confirmed = window.confirm(
        `This will update ALL employees' vacation balances:\n` +
        `Annual Leave: ${policy.entitlements?.annualLeave || 15} → ${policyDraft.entitlements?.annualLeave} days\n` +
        `Sick Leave: ${policy.entitlements?.sickLeave || 10} → ${policyDraft.entitlements?.sickLeave} days\n\n` +
        `Are you sure you want to proceed?`
      );
      
      if (!confirmed) {
        setPolicyLoading(false);
        return;
      }
    }
    
    try {
      await dataService.updatePolicy(policyDraft);
      setPolicy(policyDraft);
      setEditingPolicy(false);
      
      // Refresh employee data to show updated balances
      if (entitlementsChanged) {
        await loadData(); // Reload employees to show updated balances
        alert('Policy updated successfully! All employee vacation balances have been updated.');
      } else {
        alert('Policy updated successfully!');
      }
    } catch (e) {
      setPolicyError('Failed to save policy');
    } finally {
      setPolicyLoading(false);
    }
  };

  const handlePolicyDraftChange = (section, value) => {
    setPolicyDraft({ ...policyDraft, [section]: value });
  };

  // Login form
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="max-w-md w-full bg-white rounded-lg shadow-md p-6">
          <div className="text-center mb-6">
            <h1 className="text-2xl font-bold text-gray-900">Admin Login</h1>
            <p className="text-gray-600">NPS Team Vacation System</p>
          </div>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Username</label>
              <input
                type="text"
                value={loginForm.username}
                onChange={(e) => setLoginForm({...loginForm, username: e.target.value})}
                className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Enter username"
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
            
            {loginError && (
              <div className="text-red-600 text-sm">{loginError}</div>
            )}
            
            <button
              onClick={handleLogin}
              className="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 transition duration-200"
            >
              Login
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Error boundary
  if (hasError) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">Something went wrong</h1>
          <p className="text-gray-600 mb-4">Please refresh the page or try again later.</p>
          <button
            onClick={() => window.location.reload()}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
          >
            Refresh Page
          </button>
        </div>
      </div>
    );
  }

  const renderDashboard = () => (
    <div className="space-y-6">
      {loading && (
        <div className="text-center py-4">
          <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <p className="mt-2 text-gray-600">Loading data...</p>
        </div>
      )}
      
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        <div className="bg-blue-50 p-3 sm:p-4 rounded-lg border border-blue-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-blue-600 text-xs sm:text-sm font-medium">Pending Requests</p>
              <p className="text-xl sm:text-2xl font-bold text-blue-800">{stats.pending}</p>
            </div>
            <AlertCircle className="h-6 w-6 sm:h-8 sm:w-8 text-blue-600" />
          </div>
        </div>
        
        <div className="bg-green-50 p-3 sm:p-4 rounded-lg border border-green-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-green-600 text-xs sm:text-sm font-medium">Approved</p>
              <p className="text-xl sm:text-2xl font-bold text-green-800">{stats.approved}</p>
            </div>
            <CheckCircle className="h-6 w-6 sm:h-8 sm:w-8 text-green-600" />
          </div>
        </div>
        
        <div className="bg-purple-50 p-3 sm:p-4 rounded-lg border border-purple-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-purple-600 text-xs sm:text-sm font-medium">Total Requests</p>
              <p className="text-xl sm:text-2xl font-bold text-purple-800">{stats.totalRequests}</p>
            </div>
            <FileText className="h-6 w-6 sm:h-8 sm:w-8 text-purple-600" />
          </div>
        </div>
        
        <div className="bg-orange-50 p-3 sm:p-4 rounded-lg border border-orange-200">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-orange-600 text-xs sm:text-sm font-medium">Registered Employees</p>
              <p className="text-xl sm:text-2xl font-bold text-orange-800">{employees.length}</p>
            </div>
            <Users className="h-6 w-6 sm:h-8 sm:w-8 text-orange-600" />
          </div>
        </div>
      </div>

      <div className="bg-white rounded-lg shadow-sm border">
        <div className="p-4 border-b">
          <h3 className="text-lg font-semibold">Recent Requests</h3>
        </div>
        <div className="p-4">
          {requests.length === 0 ? (
            <p className="text-gray-500 text-center py-4">No requests submitted yet</p>
          ) : (
            requests.slice(0, 5).map(request => (
              <div key={request.id} className="flex flex-col sm:flex-row sm:items-center sm:justify-between py-3 border-b last:border-b-0 gap-2">
                <div>
                  <div className="font-medium text-sm sm:text-base">{request.employee_name}</div>
                  <div className="text-xs sm:text-sm text-gray-600">{request.type} • {request.start_date} to {request.end_date}</div>
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
        <h3 className="text-lg font-semibold">New Leave Request</h3>
        <button
          onClick={() => setShowRequestForm(false)}
          className="text-gray-500 hover:text-gray-700"
        >
          <XCircle className="h-5 w-5" />
        </button>
      </div>
      
      <div className="p-6 space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Employee *</label>
            <select
              value={newRequest.employeeId}
              onChange={(e) => setNewRequest({...newRequest, employeeId: e.target.value})}
              className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select Employee</option>
              {employees.map(emp => (
                <option key={emp.id} value={emp.id}>{emp.name} ({emp.email})</option>
              ))}
            </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Leave Type *</label>
            <select
              value={newRequest.type}
              onChange={(e) => setNewRequest({...newRequest, type: e.target.value})}
              className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Select Leave Type</option>
              {leaveTypes.map(type => (
                <option key={type.value} value={type.value}>{type.label}</option>
              ))}
            </select>
          </div>
        </div>

        {/* Date inputs - single date for Sick Leave and Exchange Off Days */}
        {renderDateInputs()}

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
        {renderPartnerInput()}

        {/* Exchange-specific fields for Exchange Off Days */}
        {newRequest.type === 'Exchange Off Days' && (
          <>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                When does the exchange partner want off? *
              </label>
              <input
                type="date"
                value={newRequest.partnerDesiredOffDate || ''}
                onChange={(e) => setNewRequest({...newRequest, partnerDesiredOffDate: e.target.value})}
                min={new Date().toISOString().split('T')[0]}
                className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Select the date exchange partner wants off"
              />
              <p className="text-xs text-gray-500 mt-1">
                This is the date the requester will work to cover for the exchange partner
              </p>
            </div>
            
            <div className="bg-blue-50 p-4 rounded-md">
              <h4 className="font-medium text-blue-800 mb-2">📅 Exchange Summary</h4>
              {newRequest.startDate && newRequest.partnerDesiredOffDate ? (
                <div className="text-sm text-blue-700 space-y-1">
                  <div>• <strong>Requester gets off:</strong> {newRequest.startDate}</div>
                  <div>• <strong>Partner gets off:</strong> {newRequest.partnerDesiredOffDate}</div>
                  <div>• <strong>Requester covers partner's shift:</strong> {newRequest.partnerDesiredOffDate}</div>
                  <div>• <strong>Partner covers requester's shift:</strong> {newRequest.startDate}</div>
                </div>
              ) : (
                <div className="text-sm text-blue-600">
                  Fill in both dates to see the exchange summary
                </div>
              )}
            </div>
          </>
        )}
        
        {renderExchangeReason()}

        {/* Show available coverage for exchange requests */}
        {newRequest.type === 'Exchange Off Days' && newRequest.startDate && (
          <div className="bg-blue-50 p-3 rounded-md">
            <p className="text-sm text-blue-800 mb-2">
              Available coverage for {newRequest.startDate}:
            </p>
            {availableCoverage.length > 0 ? (
              <div className="space-y-1">
                {availableCoverage
                  .filter(emp => emp.employee_id !== parseInt(newRequest.employeeId))
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

  const renderRequests = () => (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
        <h2 className="text-xl font-semibold">Leave Requests</h2>
        <button
          onClick={() => setShowRequestForm(true)}
          className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center justify-center gap-2 text-sm sm:text-base"
        >
          <Plus className="h-4 w-4" />
          New Request
        </button>
      </div>

      {showRequestForm && renderRequestForm()}

      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        {loading && (
          <div className="p-4 text-center text-gray-600">
            <RefreshCw className="h-6 w-6 animate-spin mx-auto mb-2" />
            Loading requests...
          </div>
        )}
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Employee</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Type</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Dates</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Days</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Coverage</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Exchange Info</th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {requests.length === 0 ? (
                <tr>
                  <td colSpan="8" className="px-6 py-4 text-center text-gray-500">
                    No requests submitted yet
                  </td>
                </tr>
              ) : (
                requests.map((request) => (
                  <tr key={request.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div>
                        <div className="text-sm font-medium text-gray-900">{request.employee_name}</div>
                        <div className="text-sm text-gray-500">{request.employee_email}</div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{request.type}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {request.start_date} to {request.end_date}
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
                          <div className="text-xs font-medium text-blue-700">Requester gets off: {request.exchange_to_date}</div>
                          {request.partner_desired_off_date && (
                            <div className="text-xs font-medium text-green-700">Partner gets off: {request.partner_desired_off_date}</div>
                          )}
                          {request.exchange_reason && (
                            <div className="text-xs text-gray-600 mt-1">{request.exchange_reason}</div>
                          )}
                          {request.exchange_partner_id && (
                            <div className="text-xs mt-1">
                              {request.exchange_partner_approved === true ? (
                                <span className="text-green-600">✓ Partner Approved</span>
                              ) : request.exchange_partner_approved === false && request.exchange_partner_approved_at ? (
                                <span className="text-red-600">✗ Partner Rejected</span>
                              ) : (
                                <span className="text-yellow-600">⏳ Waiting for Partner</span>
                              )}
                            </div>
                          )}
                          {!request.partner_desired_off_date && (
                            <div className="text-xs text-red-600 mt-1">⚠️ Missing partner's desired off date</div>
                          )}
                        </div>
                      ) : (
                        <span className="text-gray-400">-</span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium space-x-2">
                      {(request.status === 'Pending' || request.status === 'Partner Approved') && (
                        <>
                          <button
                            onClick={() => updateRequestStatus(request.id, 'Approved')}
                            className={`px-3 py-1 rounded text-white text-xs ${
                              request.status === 'Partner Approved' 
                                ? 'bg-green-600 hover:bg-green-700 animate-pulse' 
                                : 'bg-gray-400 hover:bg-green-600'
                            }`}
                          >
                            {request.status === 'Partner Approved' ? '✅ Final Approve' : 'Approve'}
                          </button>
                          <button
                            onClick={() => updateRequestStatus(request.id, 'Rejected')}
                            className="px-3 py-1 rounded bg-red-600 hover:bg-red-700 text-white text-xs"
                          >
                            Reject
                          </button>
                        </>
                      )}
                      {request.status === 'Approved' && (
                        <span className="text-green-600 text-xs">✅ Approved</span>
                      )}
                      {request.status === 'Rejected' && (
                        <span className="text-red-600 text-xs">❌ Rejected</span>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );

  const renderEmployees = () => {
    // Add error handling
    if (!employees) {
      return (
        <div className="space-y-4">
          <h2 className="text-xl font-semibold">Registered Employees</h2>
          <div className="bg-white rounded-lg shadow-sm border p-6">
            <p className="text-gray-500 text-center">Loading employees...</p>
          </div>
        </div>
      );
    }

    return (
      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center gap-3">
          <h2 className="text-xl font-semibold">Registered Employees</h2>
          <div className="flex flex-wrap gap-2">
            <button
              onClick={loadData}
              className="bg-gray-600 text-white px-3 sm:px-4 py-2 rounded-md hover:bg-gray-700 flex items-center justify-center gap-2 text-xs sm:text-sm"
              disabled={loading}
            >
              <RefreshCw className={`h-3 w-3 sm:h-4 sm:w-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
            <button
              onClick={() => setShowEmployeeForm(true)}
              className="bg-blue-600 text-white px-3 sm:px-4 py-2 rounded-md hover:bg-blue-700 flex items-center justify-center gap-2 text-xs sm:text-sm"
            >
              <Plus className="h-3 w-3 sm:h-4 sm:w-4" />
              Add Employee
            </button>
          </div>
        </div>

        {showEmployeeForm && (
          <div className="bg-white rounded-lg shadow-sm border">
            <div className="p-4 border-b flex items-center justify-between">
              <h3 className="text-lg font-semibold">Add New Employee</h3>
              <button
                onClick={() => setShowEmployeeForm(false)}
                className="text-gray-500 hover:text-gray-700"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Name *</label>
                  <input
                    type="text"
                    value={newEmployee.name}
                    onChange={(e) => setNewEmployee({...newEmployee, name: e.target.value})}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter full name"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Email *</label>
                  <input
                    type="email"
                    value={newEmployee.email}
                    onChange={(e) => setNewEmployee({...newEmployee, email: e.target.value})}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter email address"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Phone</label>
                  <input
                    type="tel"
                    value={newEmployee.phone}
                    onChange={(e) => setNewEmployee({...newEmployee, phone: e.target.value})}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter phone number"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Password *</label>
                  <input
                    type="password"
                    value={newEmployee.password}
                    onChange={(e) => setNewEmployee({...newEmployee, password: e.target.value})}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="Enter password"
                  />
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">Annual Leave Remaining</label>
                  <input
                    type="number"
                    value={newEmployee.annual_leave_remaining}
                    onChange={(e) => {
                      const value = e.target.value === '' ? 15 : parseInt(e.target.value) || 15;
                      setNewEmployee({...newEmployee, annual_leave_remaining: value});
                    }}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                    min="0"
                    max="30"
                  />
                </div>
              </div>

              <div className="flex justify-end space-x-3 pt-4">
                <button
                  onClick={() => setShowEmployeeForm(false)}
                  className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
                >
                  Cancel
                </button>
                <button
                  onClick={handleCreateEmployee}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  Create Employee
                </button>
              </div>
            </div>
          </div>
        )}
        
        <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
          {loading && (
            <div className="p-4 text-center text-gray-600">
              <RefreshCw className="h-6 w-6 animate-spin mx-auto mb-2" />
              Loading employees...
            </div>
          )}
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Employee</th>
                  <th className="hidden sm:table-cell px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                  <th className="hidden lg:table-cell px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Phone</th>
                  <th className="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Annual Leave</th>
                  <th className="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Sick Leave</th>
                  <th className="hidden md:table-cell px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Joined</th>
                  <th className="px-3 sm:px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {employees.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="px-6 py-4 text-center text-gray-500">
                      No employees registered yet
                    </td>
                  </tr>
                ) : (
                  employees.map((employee) => {
                    // Add error handling for malformed employee data
                    if (!employee || !employee.id) {
                      console.warn('Invalid employee data:', employee);
                      return null;
                    }

                    const usedAnnual = requests.filter(r => 
                      r.employee_email === employee.email && 
                      r.type === 'Annual Leave' && 
                      r.status === 'Approved'
                    ).reduce((sum, r) => sum + r.days, 0);
                    
                    const usedSick = requests.filter(r => 
                      r.employee_email === employee.email && 
                      r.type === 'Sick Leave' && 
                      r.status === 'Approved'
                    ).reduce((sum, r) => sum + r.days, 0);

                    // Use explicit remaining values if they exist, otherwise calculate from total
                    // Check if the employee has explicit remaining values set (including 0)
                    const hasExplicitAnnualRemaining = employee.annual_leave_remaining !== null && employee.annual_leave_remaining !== undefined;
                    const hasExplicitSickRemaining = employee.sick_leave_remaining !== null && employee.sick_leave_remaining !== undefined;
                    
                    const annualRemaining = hasExplicitAnnualRemaining 
                      ? employee.annual_leave_remaining 
                      : (employee.annual_leave_total || 15) - usedAnnual;
                    const sickRemaining = hasExplicitSickRemaining 
                      ? employee.sick_leave_remaining 
                      : (employee.sick_leave_total || 10) - usedSick;



                    return (
                      <tr key={employee.id} className="hover:bg-gray-50">
                        <td className="px-3 sm:px-6 py-4 whitespace-nowrap">
                          <div className="flex items-center">
                            <User className="h-4 w-4 sm:h-5 sm:w-5 text-gray-400 mr-2" />
                            <div className="text-xs sm:text-sm font-medium text-gray-900">
                              {editingEmployee?.id === employee.id ? (
                                <input
                                  type="text"
                                  value={editingEmployee.name}
                                  onChange={(e) => setEditingEmployee({...editingEmployee, name: e.target.value})}
                                  className="border border-gray-300 rounded px-2 py-1 text-sm"
                                />
                              ) : (
                                employee.name
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="hidden sm:table-cell px-3 sm:px-6 py-4 whitespace-nowrap text-xs sm:text-sm text-gray-900">
                          {editingEmployee?.id === employee.id ? (
                            <input
                              type="email"
                              value={editingEmployee.email}
                              onChange={(e) => setEditingEmployee({...editingEmployee, email: e.target.value})}
                              className="border border-gray-300 rounded px-2 py-1 text-xs sm:text-sm"
                            />
                          ) : (
                            employee.email
                          )}
                        </td>
                        <td className="hidden lg:table-cell px-3 sm:px-6 py-4 whitespace-nowrap text-xs sm:text-sm text-gray-900">
                          {editingEmployee?.id === employee.id ? (
                            <input
                              type="tel"
                              value={editingEmployee.phone}
                              onChange={(e) => setEditingEmployee({...editingEmployee, phone: e.target.value})}
                              className="border border-gray-300 rounded px-2 py-1 text-xs sm:text-sm"
                            />
                          ) : (
                            employee.phone
                          )}
                        </td>
                        <td className="px-3 sm:px-6 py-4 whitespace-nowrap">
                          {editingVacation?.id === employee.id ? (
                            <div className="space-y-2">
                              <div className="text-xs font-medium text-gray-700">Annual Leave</div>
                              <div className="space-y-1">
                                <div className="flex items-center space-x-2">
                                  <label className="text-xs text-gray-500">Remaining:</label>
                                  <input
                                    type="number"
                                    value={editingVacation.annual_leave_remaining}
                                    onChange={(e) => {
                                      const value = e.target.value === '' ? 0 : parseInt(e.target.value) || 0;
                                      setEditingVacation({...editingVacation, annual_leave_remaining: value});
                                    }}
                                    className="w-16 border border-gray-300 rounded px-2 py-1 text-xs"
                                    min="0"
                                    max="30"
                                  />
                                </div>
                                <div className="flex items-center space-x-2">
                                  <label className="text-xs text-gray-500">Total Allowed:</label>
                                  <input
                                    type="number"
                                    value={editingVacation.annual_leave_total || (policy?.entitlements?.annualLeave || 15)}
                                    onChange={(e) => {
                                      const value = e.target.value === '' ? 15 : parseInt(e.target.value) || 15;
                                      setEditingVacation({...editingVacation, annual_leave_total: value});
                                    }}
                                    className="w-16 border border-gray-300 rounded px-2 py-1 text-xs"
                                    min="0"
                                    max="30"
                                  />
                                </div>
                              </div>
                            </div>
                          ) : (
                            <div>
                              <div className="text-sm text-gray-900">
                                {annualRemaining} / {employee.annual_leave_total || policy?.entitlements?.annualLeave || 15} remaining
                              </div>
                              <div className="w-24 bg-gray-200 rounded-full h-2">
                                <div 
                                  className="bg-blue-600 h-2 rounded-full" 
                                  style={{width: `${((employee.annual_leave_total || policy?.entitlements?.annualLeave || 15) - annualRemaining) / (employee.annual_leave_total || policy?.entitlements?.annualLeave || 15) * 100}%`}}
                                ></div>
                              </div>
                            </div>
                          )}
                        </td>
                        <td className="px-3 sm:px-6 py-4 whitespace-nowrap">
                          {editingVacation?.id === employee.id ? (
                            <div className="space-y-2">
                              <div className="text-xs font-medium text-gray-700">Sick Leave</div>
                              <div className="space-y-1">
                                <div className="flex items-center space-x-2">
                                  <label className="text-xs text-gray-500">Remaining:</label>
                                  <input
                                    type="number"
                                    value={editingVacation.sick_leave_remaining}
                                    onChange={(e) => {
                                      const value = e.target.value === '' ? 0 : parseInt(e.target.value) || 0;
                                      setEditingVacation({...editingVacation, sick_leave_remaining: value});
                                    }}
                                    className="w-16 border border-gray-300 rounded px-2 py-1 text-xs"
                                    min="0"
                                    max="30"
                                  />
                                </div>
                                <div className="flex items-center space-x-2">
                                  <label className="text-xs text-gray-500">Total Allowed:</label>
                                  <input
                                    type="number"
                                    value={editingVacation.sick_leave_total || (policy?.entitlements?.sickLeave || 10)}
                                    onChange={(e) => {
                                      const value = e.target.value === '' ? 10 : parseInt(e.target.value) || 10;
                                      setEditingVacation({...editingVacation, sick_leave_total: value});
                                    }}
                                    className="w-16 border border-gray-300 rounded px-2 py-1 text-xs"
                                    min="0"
                                    max="30"
                                  />
                                </div>
                              </div>
                            </div>
                          ) : (
                            <div>
                              <div className="text-sm text-gray-900">
                                {sickRemaining} / {employee.sick_leave_total || policy?.entitlements?.sickLeave || 10} remaining
                              </div>
                              <div className="w-24 bg-gray-200 rounded-full h-2">
                                <div 
                                  className="bg-green-600 h-2 rounded-full" 
                                  style={{width: `${((employee.sick_leave_total || policy?.entitlements?.sickLeave || 10) - sickRemaining) / (employee.sick_leave_total || policy?.entitlements?.sickLeave || 10) * 100}%`}}
                                ></div>
                              </div>
                            </div>
                          )}
                        </td>
                        <td className="hidden md:table-cell px-3 sm:px-6 py-4 whitespace-nowrap text-xs sm:text-sm text-gray-500">
                          {new Date(employee.created_at).toLocaleDateString()}
                        </td>
                        <td className="px-3 sm:px-6 py-4 whitespace-nowrap text-xs sm:text-sm font-medium space-x-1 sm:space-x-2">
                          {editingEmployee?.id === employee.id ? (
                            <>
                              <button
                                onClick={handleEditEmployee}
                                className="text-green-600 hover:text-green-900"
                                title="Save changes"
                              >
                                <Save className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                              <button
                                onClick={() => setEditingEmployee(null)}
                                className="text-gray-600 hover:text-gray-900"
                                title="Cancel edit"
                              >
                                <X className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                            </>
                          ) : editingVacation?.id === employee.id ? (
                            <>
                              <button
                                onClick={handleUpdateVacationBalance}
                                className="text-green-600 hover:text-green-900"
                                title="Save vacation balance"
                              >
                                <Save className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                              <button
                                onClick={() => setEditingVacation(null)}
                                className="text-gray-600 hover:text-gray-900"
                                title="Cancel edit"
                              >
                                <X className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                            </>
                          ) : (
                            <>
                              <button
                                onClick={() => setEditingEmployee(employee)}
                                className="text-blue-600 hover:text-blue-900"
                                title="Edit employee"
                              >
                                <Edit className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                              <button
                                onClick={() => setEditingVacation(employee)}
                                className="text-purple-600 hover:text-purple-900"
                                title="Edit vacation balance"
                              >
                                <Calendar className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                              <button
                                onClick={() => handleDeleteEmployee(employee.id)}
                                className="text-red-600 hover:text-red-900"
                                title="Delete employee"
                              >
                                <Trash2 className="h-3 w-3 sm:h-4 sm:w-4" />
                              </button>
                            </>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    );
  };

  const renderPolicies = () => (
    <div className="space-y-6">
      <h2 className="text-xl font-semibold">Leave Policies & Guidelines</h2>
      {policyLoading ? (
        <div>Loading...</div>
      ) : policyError ? (
        <div className="text-red-600">{policyError}</div>
      ) : editingPolicy ? (
        <div className="space-y-4">
          {/* Edit leave types */}
          <div>
            <label className="block font-medium mb-1">Leave Types (JSON)</label>
            <textarea
              className="w-full border rounded p-2 font-mono text-xs"
              rows={8}
              value={JSON.stringify(policyDraft?.leaveTypes || [], null, 2)}
              onChange={e => {
                try {
                  handlePolicyDraftChange('leaveTypes', JSON.parse(e.target.value));
                } catch (err) {
                  // Invalid JSON, don't update
                }
              }}
            />
          </div>
          
          {/* Edit entitlements */}
          <div>
            <label className="block font-medium mb-1">Entitlements (JSON)</label>
            <textarea
              className="w-full border rounded p-2 font-mono text-xs"
              rows={4}
              value={JSON.stringify(policyDraft?.entitlements || {}, null, 2)}
              onChange={e => {
                try {
                  handlePolicyDraftChange('entitlements', JSON.parse(e.target.value));
                } catch (err) {
                  // Invalid JSON, don't update
                }
              }}
            />
          </div>
          
          {/* Edit guidelines */}
          <div>
            <label className="block font-medium mb-1">Guidelines (JSON)</label>
            <textarea
              className="w-full border rounded p-2 font-mono text-xs"
              rows={6}
              value={JSON.stringify(policyDraft?.guidelines || {}, null, 2)}
              onChange={e => {
                try {
                  handlePolicyDraftChange('guidelines', JSON.parse(e.target.value));
                } catch (err) {
                  // Invalid JSON, don't update
                }
              }}
            />
          </div>
          
          <div className="flex gap-2">
            <button onClick={handlePolicySave} className="bg-blue-600 text-white px-4 py-2 rounded">Publish</button>
            <button onClick={handlePolicyCancel} className="bg-gray-300 px-4 py-2 rounded">Cancel</button>
          </div>
        </div>
      ) : policy ? (
        <div>
          {/* Display policy sections in a readable format */}
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
              <h3 className="text-lg font-semibold mb-4 text-green-800">Entitlements</h3>
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
          
          <button onClick={handlePolicyEdit} className="bg-blue-600 text-white px-4 py-2 rounded">Edit Policy</button>
        </div>
      ) : (
        <div>No policy found.</div>
      )}
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col sm:flex-row sm:justify-between sm:items-center py-4 gap-4">
            <div>
              <h1 className="text-xl sm:text-2xl font-bold text-gray-900">NPS Team - Admin Dashboard</h1>
              <p className="text-xs sm:text-sm text-gray-600">Vacation Management System • 24/7 Coverage</p>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
              <div className="text-xs sm:text-sm text-gray-600">
                <Clock className="inline h-3 w-3 sm:h-4 sm:w-4 mr-1" />
                5:00 PM - 1:00 AM Daily
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

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-6">
        <div className="flex flex-wrap gap-1 sm:gap-2 mb-4 sm:mb-6">
          {[
            { id: 'dashboard', label: 'Dashboard', icon: Calendar },
            { id: 'requests', label: 'Requests', icon: FileText },
            { id: 'employees', label: 'Employees', icon: Users },
            { id: 'schedule', label: 'Work Schedule', icon: Clock },
            { id: 'templates', label: 'Templates', icon: Copy },
            { id: 'policies', label: 'Policies', icon: FileText }
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
          {activeTab === 'dashboard' && renderDashboard()}
          {activeTab === 'requests' && renderRequests()}
          {activeTab === 'employees' && renderEmployees()}
          {activeTab === 'schedule' && <WorkScheduleManager />}
          {activeTab === 'templates' && <WorkScheduleTemplateManager />}
          {activeTab === 'policies' && renderPolicies()}
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard; 