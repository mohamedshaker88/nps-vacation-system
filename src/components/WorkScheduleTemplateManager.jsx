import React, { useState, useEffect } from "react";
import { Calendar, Plus, Save, X, Users, Clock, CheckCircle, AlertCircle, RefreshCw, Copy } from 'lucide-react';
import { dataService } from '../services/dataService';

const WorkScheduleTemplateManager = () => {
  const [templates, setTemplates] = useState([]);
  const [employees, setEmployees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [showAddTemplate, setShowAddTemplate] = useState(false);
  const [selectedEmployee, setSelectedEmployee] = useState(null);
  const [editingTemplate, setEditingTemplate] = useState(null);
  const [generatingSchedules, setGeneratingSchedules] = useState(false);

  const daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const dayColumns = ['monday_status', 'tuesday_status', 'wednesday_status', 'thursday_status', 'friday_status', 'saturday_status', 'sunday_status'];

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    setError('');
    try {
      console.log('Loading work schedule data...');
      const [templatesData, employeesData] = await Promise.all([
        dataService.getWorkScheduleTemplates(),
        dataService.getEmployees()
      ]);
      
      console.log('Templates loaded:', templatesData);
      console.log('Employees loaded:', employeesData);
      
      setTemplates(templatesData || []);
      setEmployees(employeesData || []);
    } catch (err) {
      console.error('Error loading work schedule data:', err);
      setError('Failed to load work schedule templates: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const getTemplateForEmployee = (employeeId) => {
    return templates.find(t => t.employee_id === employeeId);
  };

  const handleStatusChange = async (employeeId, dayColumn, newStatus) => {
    try {
      let template = getTemplateForEmployee(employeeId);
      
      if (!template) {
        // Create new template if it doesn't exist
        console.log('Creating new template for employee:', employeeId);
        template = await dataService.createDefaultTemplateForEmployee(employeeId);
        setTemplates([...templates, template]);
      }

      const updatedTemplate = await dataService.updateWorkScheduleTemplate(template.id, {
        [dayColumn]: newStatus
      });

      setTemplates(templates.map(t => 
        t.id === template.id ? updatedTemplate : t
      ));
    } catch (err) {
      console.error('Error updating template:', err);
      setError('Failed to update template: ' + err.message);
    }
  };

  const addTemplateForEmployee = async (employeeId) => {
    try {
      console.log('Adding template for employee:', employeeId);
      const template = await dataService.createDefaultTemplateForEmployee(employeeId);
      console.log('Template created:', template);
      setTemplates([...templates, template]);
      setShowAddTemplate(false);
      setSelectedEmployee(null);
    } catch (err) {
      console.error('Error adding template for employee:', err);
      setError('Failed to add template for employee: ' + err.message);
    }
  };

  const removeTemplateForEmployee = async (templateId) => {
    try {
      await dataService.deleteWorkScheduleTemplate(templateId);
      setTemplates(templates.filter(t => t.id !== templateId));
    } catch (err) {
      console.error('Error removing template:', err);
      setError('Failed to remove template: ' + err.message);
    }
  };

  const getEmployeesWithoutTemplates = () => {
    const templatedEmployeeIds = templates.map(t => t.employee_id);
    const availableEmployees = employees.filter(emp => !templatedEmployeeIds.includes(emp.id));
    console.log('Employees without templates:', availableEmployees);
    return availableEmployees;
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

  const generateSchedulesForCurrentWeek = async () => {
    try {
      setGeneratingSchedules(true);
      setError('');
      
      // Get current week start (Monday)
      const today = new Date();
      const dayOfWeek = today.getDay();
      const daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      const weekStart = new Date(today.setDate(today.getDate() - daysToSubtract));
      const weekStartDate = weekStart.toISOString().split('T')[0];
      
      await dataService.generateWeekSchedules(weekStartDate);
      
      alert('Schedules generated successfully for the current week!');
    } catch (err) {
      console.error('Error generating schedules:', err);
      setError('Failed to generate schedules: ' + err.message);
    } finally {
      setGeneratingSchedules(false);
    }
  };

  const copyTemplateToEmployee = async (sourceEmployeeId, targetEmployeeId) => {
    try {
      const sourceTemplate = getTemplateForEmployee(sourceEmployeeId);
      if (!sourceTemplate) {
        setError('Source template not found');
        return;
      }

      const newTemplate = {
        employee_id: targetEmployeeId,
        monday_status: sourceTemplate.monday_status,
        tuesday_status: sourceTemplate.tuesday_status,
        wednesday_status: sourceTemplate.wednesday_status,
        thursday_status: sourceTemplate.thursday_status,
        friday_status: sourceTemplate.friday_status,
        saturday_status: sourceTemplate.saturday_status,
        sunday_status: sourceTemplate.sunday_status,
        is_active: true
      };

      const createdTemplate = await dataService.saveWorkScheduleTemplate(newTemplate);
      setTemplates([...templates, createdTemplate]);
      alert('Template copied successfully!');
    } catch (err) {
      console.error('Error copying template:', err);
      setError('Failed to copy template: ' + err.message);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span className="ml-2">Loading work schedule templates...</span>
      </div>
    );
  }

  const employeesWithoutTemplates = getEmployeesWithoutTemplates();

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold">Work Schedule Templates</h2>
          <p className="text-sm text-gray-600">
            Manage recurring weekly work schedule templates for employees
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          <button
            onClick={generateSchedulesForCurrentWeek}
            disabled={generatingSchedules}
            className="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 flex items-center gap-2"
          >
            <RefreshCw className={`h-4 w-4 ${generatingSchedules ? 'animate-spin' : ''}`} />
            Generate Week Schedules
          </button>
          <button
            onClick={() => setShowAddTemplate(true)}
            className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 flex items-center gap-2"
          >
            <Plus className="h-4 w-4" />
            Add Template
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

      {/* Debug Info */}
      <div className="bg-gray-50 p-4 rounded-md text-sm">
        <p><strong>Debug Info:</strong></p>
        <p>Total Employees: {employees.length}</p>
        <p>Total Templates: {templates.length}</p>
        <p>Employees without templates: {employeesWithoutTemplates.length}</p>
      </div>

      {/* Template Table */}
      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Employee
                </th>
                {daysOfWeek.map((day, index) => (
                  <th key={day} className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    {day}
                  </th>
                ))}
                <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {templates.length === 0 ? (
                <tr>
                  <td colSpan="9" className="px-6 py-4 text-center text-gray-500">
                    No templates created yet
                  </td>
                </tr>
              ) : (
                templates.map((template) => {
                  const employee = employees.find(emp => emp.id === template.employee_id);
                  if (!employee) return null;

                  return (
                    <tr key={template.id} className="hover:bg-gray-50">
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
                              template.employee_id, 
                              dayColumn, 
                              template[dayColumn] === 'working' ? 'off' : 'working'
                            )}
                            className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-medium transition-colors ${
                              getStatusColor(template[dayColumn])
                            } hover:opacity-80`}
                          >
                            {getStatusIcon(template[dayColumn])}
                            <span className="ml-1">
                              {template[dayColumn] === 'working' ? 'Working' : 'Off'}
                            </span>
                          </button>
                        </td>
                      ))}
                      
                      <td className="px-6 py-4 whitespace-nowrap text-center">
                        <div className="flex justify-center space-x-2">
                          <button
                            onClick={() => removeTemplateForEmployee(template.id)}
                            className="text-red-600 hover:text-red-900 text-sm"
                          >
                            Remove
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Template Modal */}
      {showAddTemplate && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Add Template for Employee</h3>
              
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
                    {employeesWithoutTemplates.map(emp => (
                      <option key={emp.id} value={emp.id}>
                        {emp.name} ({emp.email})
                      </option>
                    ))}
                  </select>
                  {employeesWithoutTemplates.length === 0 && (
                    <p className="text-sm text-gray-500 mt-1">
                      All employees already have templates
                    </p>
                  )}
                </div>
                
                <div className="flex justify-end space-x-3 pt-4">
                  <button
                    onClick={() => {
                      setShowAddTemplate(false);
                      setSelectedEmployee(null);
                    }}
                    className="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => addTemplateForEmployee(selectedEmployee)}
                    disabled={!selectedEmployee}
                    className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    Add Template
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Legend */}
      <div className="bg-white rounded-lg shadow-sm border p-4">
        <h4 className="font-medium text-gray-900 mb-3">Template Legend</h4>
        <div className="flex flex-wrap gap-4">
          <div className="flex items-center">
            <Clock className="h-4 w-4 text-blue-600 mr-2" />
            <span className="text-sm text-gray-600">Working Day (Default)</span>
          </div>
          <div className="flex items-center">
            <CheckCircle className="h-4 w-4 text-green-600 mr-2" />
            <span className="text-sm text-gray-600">Off Day (Default)</span>
          </div>
        </div>
        <p className="text-xs text-gray-500 mt-2">
          Click on any day to toggle between working and off status. These templates will be used to generate weekly schedules.
        </p>
      </div>

      {/* Information Panel */}
      <div className="bg-blue-50 rounded-lg border border-blue-200 p-4">
        <h4 className="font-medium text-blue-900 mb-2">How Templates Work</h4>
        <ul className="text-sm text-blue-800 space-y-1">
          <li>• Templates define the default weekly schedule for each employee</li>
          <li>• When a new week is viewed, schedules are automatically generated from templates</li>
          <li>• Approved leave requests automatically override template schedules</li>
          <li>• Use "Generate Week Schedules" to create schedules for the current week</li>
          <li>• Changes to templates only affect future weeks, not existing schedules</li>
        </ul>
      </div>
    </div>
  );
};

export default WorkScheduleTemplateManager;
