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

  async updateEmployeeVacationBalance(id, annualLeaveRemaining, sickLeaveRemaining) {
    const { data, error } = await supabase
      .from('employees')
      .update({ 
        annual_leave_remaining: annualLeaveRemaining,
        sick_leave_remaining: sickLeaveRemaining
      })
      .eq('id', id)
      .select()
    
    if (error) throw error
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
    const { data, error } = await supabase
      .from('policies')
      .select('*')
      .eq('published', true)
      .order('updated_at', { ascending: false })
      .limit(1)
      .single();
    if (error) throw error;
    return data;
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
      
      // Update all employees with new balances
      const { error: updateError } = await supabase
        .from('employees')
        .update({ 
          annual_leave_remaining: annualLeave,
          sick_leave_remaining: sickLeave
        });
      
      if (updateError) {
        console.error('Error updating employee balances:', updateError);
        // Don't throw error here to avoid rolling back policy update
      }
    }
    
    return data;
  }
} 