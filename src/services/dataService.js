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
  }
} 