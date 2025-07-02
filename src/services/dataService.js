import { supabase } from '../supabase'

export const dataService = {
  // Employee operations
  async saveEmployee(employee) {
    const { data, error } = await supabase
      .from('employees')
      .upsert([employee], { onConflict: 'email' })
    
    if (error) throw error
    return data
  },

  async getEmployees() {
    const { data, error } = await supabase
      .from('employees')
      .select('*')
      .order('created_at', { ascending: false })
    
    if (error) throw error
    
    console.log('Retrieved employees from database:', data);
    return data || []
  },

  async getEmployeeByEmail(email) {
    const { data, error } = await supabase
      .from('employees')
      .select('*')
      .eq('email', email)
      .single()
    
    if (error) throw error
    return data
  },

  async deleteEmployee(id) {
    const { error } = await supabase
      .from('employees')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    return true
  },

  async updateEmployee(id, updates) {
    const { data, error } = await supabase
      .from('employees')
      .update(updates)
      .eq('id', id)
      .select()
    
    if (error) throw error
    return data[0]
  },

  async updateEmployeeVacationBalance(id, annualLeaveRemaining, sickLeaveRemaining, annualLeaveTotal, sickLeaveTotal) {
    const updateData = { 
      annual_leave_remaining: annualLeaveRemaining,
      sick_leave_remaining: sickLeaveRemaining,
      annual_leave_total: annualLeaveTotal,
      sick_leave_total: sickLeaveTotal
    };
    
    console.log('Sending update data to database:', { id, updateData });
    
    const { data, error } = await supabase
      .from('employees')
      .update(updateData)
      .eq('id', id)
      .select()
    
    if (error) {
      console.error('Error updating vacation balance:', error);
      throw error;
    }
    
    console.log('Database response:', data[0]);
    return data[0]
  },

  // Request operations
  async saveRequest(request) {
    const { data, error } = await supabase
      .from('requests')
      .insert([request])
      .select()
    
    if (error) throw error
    return data[0]
  },

  async getRequests() {
    const { data, error } = await supabase
      .from('requests')
      .select('*')
      .order('created_at', { ascending: false })
    
    if (error) throw error
    return data || []
  },

  async getRequestsByEmployee(email) {
    const { data, error } = await supabase
      .from('requests')
      .select('*')
      .eq('employee_email', email)
      .order('created_at', { ascending: false })
    
    if (error) throw error
    return data || []
  },

  async updateRequestStatus(requestId, status) {
    const { data, error } = await supabase
      .from('requests')
      .update({ status })
      .eq('id', requestId)
      .select()
    
    if (error) throw error
    return data[0]
  },

  // Authentication
  async authenticateEmployee(email, password) {
    const { data, error } = await supabase
      .from('employees')
      .select('*')
      .eq('email', email)
      .eq('password', password)
      .single()
    
    if (error) throw error
    return data
  },

  // Check if email exists
  async checkEmailExists(email) {
    const { data, error } = await supabase
      .from('employees')
      .select('email')
      .eq('email', email)
      .single()
    
    if (error && error.code !== 'PGRST116') throw error
    return !!data
  },

  // Policy operations
  async getCurrentPolicy() {
    try {
      const { data, error } = await supabase
        .from('policies')
        .select('*')
        .eq('published', true)
        .order('updated_at', { ascending: false })
        .limit(1)
        .single();
      
      if (error) {
        console.error('Error fetching policy:', error);
        // Return null if no policy found or table doesn't exist
        return null;
      }
      return data;
    } catch (error) {
      console.error('Exception in getCurrentPolicy:', error);
      return null;
    }
  },

  async updatePolicy(content) {
    // Unpublish all current policies
    await supabase.from('policies').update({ published: false }).eq('published', true);
    
    // Insert new published policy
    const { data, error } = await supabase
      .from('policies')
      .insert([{ content, published: true }])
      .select()
      .single();
    
    if (error) throw error;
    
    // Update all employees' vacation balances based on new policy
    if (content.entitlements) {
      const { annualLeave, sickLeave } = content.entitlements;
      
      // Update all employees with new balances and totals
      const { error: updateError } = await supabase
        .from('employees')
        .update({ 
          annual_leave_remaining: annualLeave,
          sick_leave_remaining: sickLeave,
          annual_leave_total: annualLeave,
          sick_leave_total: sickLeave
        });
      
      if (updateError) {
        console.error('Error updating employee balances:', updateError);
        // Don't throw error here to avoid rolling back policy update
      }
    }
    
    return data;
  },

  // Work Schedule operations
  async getWorkSchedules(weekStartDate = null) {
    if (!weekStartDate) {
      // Get current week start (Monday)
      const today = new Date();
      const dayOfWeek = today.getDay();
      const daysToSubtract = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Convert Sunday=0 to Monday=0
      weekStartDate = new Date(today.setDate(today.getDate() - daysToSubtract));
      weekStartDate = weekStartDate.toISOString().split('T')[0];
    }

    const { data, error } = await supabase
      .from('work_schedules')
      .select(`
        *,
        employees (
          id,
          name,
          email
        )
      `)
      .eq('week_start_date', weekStartDate)
      .order('employees(name)')
    
    if (error) throw error
    return data || []
  },

  async getWorkScheduleByEmployee(employeeId, weekStartDate) {
    const { data, error } = await supabase
      .from('work_schedules')
      .select('*')
      .eq('employee_id', employeeId)
      .eq('week_start_date', weekStartDate)
      .single()
    
    if (error && error.code !== 'PGRST116') throw error
    return data
  },

  async saveWorkSchedule(schedule) {
    const { data, error } = await supabase
      .from('work_schedules')
      .upsert([schedule], { 
        onConflict: 'employee_id,week_start_date',
        ignoreDuplicates: false 
      })
      .select()
    
    if (error) throw error
    return data[0]
  },

  async updateWorkSchedule(id, updates) {
    const { data, error } = await supabase
      .from('work_schedules')
      .update(updates)
      .eq('id', id)
      .select()
    
    if (error) throw error
    return data[0]
  },

  async deleteWorkSchedule(id) {
    const { error } = await supabase
      .from('work_schedules')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    return true
  },

  async getAvailableCoverage(date) {
    try {
      const { data, error } = await supabase
        .rpc('get_available_coverage', { p_date: date })
      
      if (error) throw error
      return data || []
    } catch (error) {
      console.error('Error getting available coverage:', error);
      // Fallback: return all employees as available
      const { data: employees, error: empError } = await supabase
        .from('employees')
        .select('id, name, email')
        .order('name')
      
      if (empError) throw empError
      return employees.map(emp => ({
        employee_id: emp.id,
        employee_name: emp.name,
        employee_email: emp.email,
        day_status: 'off'
      }))
    }
  },

  async getEmployeeDayStatus(employeeId, date) {
    try {
      const { data, error } = await supabase
        .rpc('get_employee_day_status', { 
          p_employee_id: employeeId, 
          p_date: date 
        })
      
      if (error) throw error
      return data
    } catch (error) {
      console.error('Error getting employee day status:', error);
      // Fallback: return default schedule
      const dayOfWeek = new Date(date).getDay();
      return dayOfWeek === 0 || dayOfWeek === 6 ? 'off' : 'working';
    }
  },

  async createDefaultScheduleForEmployee(employeeId, weekStartDate) {
    const defaultSchedule = {
      employee_id: employeeId,
      week_start_date: weekStartDate,
      monday_status: 'working',
      tuesday_status: 'working',
      wednesday_status: 'working',
      thursday_status: 'working',
      friday_status: 'working',
      saturday_status: 'off',
      sunday_status: 'off'
    };

    return await this.saveWorkSchedule(defaultSchedule);
  },

  // Work Schedule Template operations
  async getWorkScheduleTemplates() {
    const { data, error } = await supabase
      .from('work_schedule_templates')
      .select(`
        *,
        employees (
          id,
          name,
          email
        )
      `)
      .eq('is_active', true)
      .order('employees(name)')
    
    if (error) throw error
    return data || []
  },

  async getWorkScheduleTemplateByEmployee(employeeId) {
    const { data, error } = await supabase
      .from('work_schedule_templates')
      .select('*')
      .eq('employee_id', employeeId)
      .eq('is_active', true)
      .single()
    
    if (error && error.code !== 'PGRST116') throw error
    return data
  },

  async saveWorkScheduleTemplate(template) {
    const { data, error } = await supabase
      .from('work_schedule_templates')
      .upsert([template], { 
        onConflict: 'employee_id',
        ignoreDuplicates: false 
      })
      .select()
    
    if (error) throw error
    return data[0]
  },

  async updateWorkScheduleTemplate(id, updates) {
    const { data, error } = await supabase
      .from('work_schedule_templates')
      .update(updates)
      .eq('id', id)
      .select()
    
    if (error) throw error
    return data[0]
  },

  async deleteWorkScheduleTemplate(id) {
    const { error } = await supabase
      .from('work_schedule_templates')
      .delete()
      .eq('id', id)
    
    if (error) throw error
    return true
  },

  async generateWeekSchedules(weekStartDate) {
    const { data, error } = await supabase
      .rpc('generate_week_schedules', { p_week_start_date: weekStartDate })
    
    if (error) throw error
    return data
  },

  async createDefaultTemplateForEmployee(employeeId) {
    const defaultTemplate = {
      employee_id: employeeId,
      monday_status: 'working',
      tuesday_status: 'working',
      wednesday_status: 'working',
      thursday_status: 'working',
      friday_status: 'working',
      saturday_status: 'off',
      sunday_status: 'off',
      is_active: true
    };

    return await this.saveWorkScheduleTemplate(defaultTemplate);
  },

  // Exchange approval functions
  async getPendingExchangeApprovals(employeeId) {
    const { data, error } = await supabase
      .rpc('get_pending_exchange_approvals', { p_employee_id: employeeId })
    
    if (error) throw error
    return data || []
  },

  async approveExchangeRequest(requestId, employeeId, approved, notes = null) {
    const { data, error } = await supabase
      .rpc('approve_exchange_request', { 
        p_request_id: requestId,
        p_employee_id: employeeId,
        p_approved: approved,
        p_notes: notes
      })
    
    if (error) throw error
    return data
  },

  async validateExchangeRequest(employeeId, exchangeFromDate, exchangeToDate, exchangePartnerId) {
    const { data, error } = await supabase
      .rpc('validate_exchange_request', { 
        p_employee_id: employeeId,
        p_exchange_from_date: exchangeFromDate,
        p_exchange_to_date: exchangeToDate,
        p_exchange_partner_id: exchangePartnerId
      })
    
    if (error) throw error
    return data[0] || { is_valid: false, error_message: 'Validation failed' }
  },

  // Notification functions
  async getNotifications(employeeId) {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('employee_id', employeeId)
      .order('created_at', { ascending: false })
    
    if (error) throw error
    return data || []
  },

  async markNotificationAsRead(notificationId) {
    const { data, error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId)
      .select()
    
    if (error) throw error
    return data[0]
  },

  async getUnreadNotificationCount(employeeId) {
    const { count, error } = await supabase
      .from('notifications')
      .select('*', { count: 'exact', head: true })
      .eq('employee_id', employeeId)
      .eq('is_read', false)
    
    if (error) throw error
    return count || 0
  }
} 