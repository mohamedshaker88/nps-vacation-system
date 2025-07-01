-- NPS Team Vacation Management System Database Setup
-- Run this script in your Supabase SQL Editor

-- Create employees table
CREATE TABLE employees (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(50),
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create requests table
CREATE TABLE requests (
  id BIGSERIAL PRIMARY KEY,
  employee_name VARCHAR(255) NOT NULL,
  employee_email VARCHAR(255) NOT NULL,
  type VARCHAR(100) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  days INTEGER NOT NULL,
  reason TEXT,
  status VARCHAR(50) DEFAULT 'Pending',
  submit_date DATE NOT NULL,
  coverage_arranged BOOLEAN DEFAULT FALSE,
  coverage_by VARCHAR(255),
  emergency_contact VARCHAR(255),
  additional_notes TEXT,
  medical_certificate BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_requests_employee_email ON requests(employee_email);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_requests_created_at ON requests(created_at DESC);
CREATE INDEX idx_employees_created_at ON employees(created_at DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE requests ENABLE ROW LEVEL SECURITY;

-- Create policies for employees table
CREATE POLICY "Employees can view their own data" ON employees
  FOR SELECT USING (email = current_user);

CREATE POLICY "Employees can insert their own data" ON employees
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Employees can update their own data" ON employees
  FOR UPDATE USING (email = current_user);

-- Create policies for requests table
CREATE POLICY "Employees can view their own requests" ON requests
  FOR SELECT USING (employee_email = current_user);

CREATE POLICY "Employees can insert their own requests" ON requests
  FOR INSERT WITH CHECK (employee_email = current_user);

CREATE POLICY "Employees can update their own requests" ON requests
  FOR UPDATE USING (employee_email = current_user);

-- Admin policies (for admin dashboard)
CREATE POLICY "Admin can view all employees" ON employees
  FOR SELECT USING (true);

CREATE POLICY "Admin can view all requests" ON requests
  FOR SELECT USING (true);

CREATE POLICY "Admin can update request status" ON requests
  FOR UPDATE USING (true);

-- Insert sample data (optional)
INSERT INTO employees (name, email, phone, password) VALUES
  ('John Doe', 'john.doe@technetworkinc.com', '+1234567890', 'password123'),
  ('Jane Smith', 'jane.smith@technetworkinc.com', '+1234567891', 'password123'),
  ('Mike Johnson', 'mike.johnson@technetworkinc.com', '+1234567892', 'password123');

-- Insert sample requests (optional)
INSERT INTO requests (employee_name, employee_email, type, start_date, end_date, days, reason, status, submit_date, coverage_arranged, coverage_by) VALUES
  ('John Doe', 'john.doe@technetworkinc.com', 'Annual Leave', '2024-01-15', '2024-01-19', 5, 'Family vacation', 'Approved', '2024-01-01', true, 'Jane Smith'),
  ('Jane Smith', 'jane.smith@technetworkinc.com', 'Sick Leave', '2024-01-10', '2024-01-10', 1, 'Not feeling well', 'Approved', '2024-01-09', true, 'Mike Johnson'),
  ('Mike Johnson', 'mike.johnson@technetworkinc.com', 'Emergency Leave', '2024-01-20', '2024-01-22', 3, 'Family emergency', 'Pending', '2024-01-18', false, NULL); 