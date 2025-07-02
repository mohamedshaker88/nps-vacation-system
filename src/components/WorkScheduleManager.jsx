import React, { useState, useEffect } from "react";
import { Calendar, ChevronLeft, ChevronRight, Plus, Save, X, Users, Clock, CheckCircle, AlertCircle } from 'lucide-react';
import { dataService } from '../services/dataService';

const WorkScheduleManager = () => {
  const [currentWeek, setCurrentWeek] = useState(new Date());
  const [schedules, setSchedules] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAddEmployee, setShowAddEmployee] = useState(false);
  const [selectedEmployee, setSelectedEmployee] = useState(null);

  const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const dayColumns = ['monday_status', 'tuesday_status', 'wednesday_status', 'thursday_status', 'friday_status', 'saturday_status', 'sunday_status'];

  useEffect(() => {
    loadData();
  }, [currentWeek]);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      const weekStart = getWeekStart(currentWeek);
      const [schedulesData, employeesData] = await Promise.all([
        dataService.getWorkSchedules(weekStart),
        dataService.getEmployees()
      ]);
      
      setSchedules(schedulesData);
      setEmployees(employeesData);
    } catch (err) {
      setError('Failed to load work schedules');
      console.error('Error loading data:', err);
    } finally {
      setLoading(false);
    }
  };

  const getWeekStart = (date) => {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    const monday = new Date(d.setDate(diff));
    return monday.toISOString().split('T')[0];
  };

  const getWeekEnd = (date) => {
    const weekStart = getWeekStart(date);
    const end = new Date(weekStart);
    end.setDate(end.getDate() + 6);
    return end.toISOString().split('T')[0];
  };

  const formatDate = (date) => {
    return new Date(date).toLocaleDateString('en-US', { 
      weekday: 'short', 
      month: 'short', 
      day: 'numeric' 
    });
  };

  const getWeekDates = () => {
    const weekStart = getWeekStart(currentWeek);
    const dates = [];
    for (let i = 0; i < 7; i++) {
      const date = new Date(weekStart);
      date.setDate(date.getDate() + i);
      dates.push(date.toISOString().split('T')[0]);
    }
    return dates;
  };

  const navigateWeek = (direction) => {
    const newWeek = new Date(currentWeek);
    newWeek.setDate(newWeek.getDate() + (direction * 7));
    setCurrentWeek(newWeek);
  };

  const getScheduleForEmployee = (employeeId) => {
    return schedules.find(s => s.employee_id === employeeId);
  };

  const handleStatusChange = async (employeeId, dayColumn, newStatus) => {
    try {
      const weekStart = getWeekStart(currentWeek);
      let schedule = getScheduleForEmployee(employeeId);
      
      if (!schedule) {
        schedule = await dataService.createDefaultScheduleForEmployee(employeeId, weekStart);
        setSchedules([...schedules, schedule]);
      }

      const updatedSchedule = await dataService.updateWorkSchedule(schedule.id, {
        [dayColumn]: newStatus
      });

      setSchedules(schedules.map(s => 
        s.id === schedule.id ? updatedSchedule : s
      ));
    } catch (err) {
      setError('Failed to update schedule');
      console.error('Error updating schedule:', err);
    }
  };

  const addEmployeeToSchedule = async (employeeId) => {
    try {
      const weekStart = getWeekStart(currentWeek);
      const schedule = await dataService.createDefaultScheduleForEmployee(employeeId, weekStart);
      setSchedules([...schedules, schedule]);
      setShowAddEmployee(false);
      setSelectedEmployee(null);
    } catch (err) {
      setError('Failed to add employee to schedule');
      console.error('Error adding employee:', err);
    }
  };

  const removeEmployeeFromSchedule = async (scheduleId) => {
    try {
      await dataService.deleteWorkSchedule(scheduleId);
      setSchedules(schedules.filter(s => s.id !== scheduleId));
    } catch (err) {
      setError('Failed to remove employee from schedule');
      console.error('Error removing employee:', err);
    }
  };

  const getEmployeesNotInSchedule = () => {
    const scheduledEmployeeIds = schedules.map(s => s.employee_id);
    return employees.filter(emp => !scheduledEmployeeIds.includes(emp.id));
  };

  const getStatusIcon = (status) => {
    return status === 'working' ? 
      <Clock className="h-4 w-4 text-blue-600" /> : 
      <CheckCircle className="h-4 w-4 text-green-600" />;
  };

  const getStatusColor = (status) => {
    return status === 'working' ? 
      'bg-blue-100 text-blue-800' : 
      'bg-green-100 text-green-800';
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span className="ml-2">Loading work schedules...</span>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold">Work Schedule Management</h2>
          <p className="text-sm text-gray-600">
            Manage employee work schedules and off days
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowAddEmployee(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
          >
            <Plus className="h-4 w-4" />
            Add Employee
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-md p-4">
          <div className="flex items-center">
            <AlertCircle className="h-5 w-5 text-red-400 mr-2" />
            <span className="text-red-800">{error}</span>
          </div>
        </div>
      )}

      {/* Week Navigation */}
      <div className="bg-white rounded-lg shadow-sm border p-4">
        <div className="flex items-center justify-between">
          <button
            onClick={() => navigateWeek(-1)}
            className="p-2 hover:bg-gray-100 rounded-md"
          >
            <ChevronLeft className="h-5 w-5" />
          </button>
          
          <div className="text-center">
            <h3 className="text-lg font-medium">
              {formatDate(getWeekStart(currentWeek))} - {formatDate(getWeekEnd(currentWeek))}
            </h3>
            <p className="text-sm text-gray-600">Week Schedule</p>
          </div>
          
          <button
            onClick={() => navigateWeek(1)}
            className="p-2 hover:bg-gray-100 rounded-md"
          >
            <ChevronRight className="h-5 w-5" />
          </button>
        </div>
      </div>

      {/* Schedule Table */}
      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Employee
                </th>
                {getWeekDates().map((date, index) => (
                  <th key={date} className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    <div>{daysOfWeek[index]}</div>
                    <div className="text-xs text-gray-400">{formatDate(date)}</div>
                  </th>
                ))}
                <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {schedules.length === 0 ? (
                <tr>
                  <td colSpan="9" className="px-6 py-4 text-center text-gray-500">
                    No employees scheduled for this week
                  </td>
                </tr>
              ) : (
                schedules.map((schedule) => {
                  const employee = employees.find(emp => emp.id === schedule.employee_id);
                  if (!employee) return null;

                  return (
                    <tr key={schedule.id} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div>
                          <div className="text-sm font-medium text-gray-900">{employee.name}</div>
                          <div className="text-sm text-gray-500">{employee.email}</div>
                        </div>
                      </td>
                      
                      {dayColumns.map((dayColumn, index) => (
                        <td key={dayColumn} className="px-6 py-4 whitespace-nowrap text-center">
                          <button
                            onClick={() => handleStatusChange(
                              schedule.employee_id, 
                              dayColumn, 
                              schedule[dayColumn] === 'working' ? 'off' : 'working'
                            )}
                            className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium transition-colors ${
                              getStatusColor(schedule[dayColumn])
                            } hover:opacity-80`}
                          >
                            {getStatusIcon(schedule[dayColumn])}
                            <span className="ml-1">
                              {schedule[dayColumn] === 'working' ? 'Working' : 'Off'}
                            </span>
                          </button>
                        </td>
                      ))}
                      
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <button
                          onClick={() => removeEmployeeFromSchedule(schedule.id)}
                          className="text-red-600 hover:text-red-900 text-sm"
                        >
                          Remove
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Employee Modal */}
      {showAddEmployee && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Add Employee to Schedule</h3>
              
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Select Employee
                  </label>
                  <select
                    value={selectedEmployee || ''}
                    onChange={(e) => setSelectedEmployee(e.target.value)}
                    className="w-full border border-gray-300 rounded-md px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="">Choose an employee...</option>
                    {getEmployeesNotInSchedule().map(emp => (
                      <option key={emp.id} value={emp.id}>
                        {emp.name} ({emp.email})
                      </option>
                    ))}
                  </select>
                </div>
                
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    onClick={() => {
                      setShowAddEmployee(false);
                      setSelectedEmployee(null);
                    }}
                    className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => addEmployeeToSchedule(selectedEmployee)}
                    disabled={!selectedEmployee}
                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Add Employee
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Legend */}
      <div className="bg-white rounded-lg shadow-sm border p-4">
        <h4 className="font-medium text-gray-900 mb-3">Schedule Legend</h4>
        <div className="flex flex-wrap gap-4">
          <div className="flex items-center">
            <Clock className="h-4 w-4 text-blue-600 mr-2" />
            <span className="text-sm text-gray-600">Working Day</span>
          </div>
          <div className="flex items-center">
            <CheckCircle className="h-4 w-4 text-green-600 mr-2" />
            <span className="text-sm text-gray-600">Off Day</span>
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-2">
          Click on any day to toggle between working and off status
        </p>
      </div>
    </div>
  );
};

export default WorkScheduleManager;
