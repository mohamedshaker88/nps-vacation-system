# Work Schedule Automation & Recurring Templates

## Overview

The Vacation Management System now includes a comprehensive automation system for work schedules with recurring templates. This system automatically generates weekly schedules from templates and updates them when leave requests are approved.

## Key Features

### 1. Recurring Work Schedule Templates
- **Template Management**: Create and manage weekly recurring schedules for each employee
- **Default Patterns**: Set default working/off days for each day of the week
- **Visual Interface**: Easy-to-use table interface for managing templates
- **Bulk Operations**: Generate schedules for all employees at once

### 2. Automatic Schedule Generation
- **On-Demand Generation**: Generate schedules for any week using templates
- **Automatic Creation**: Schedules are automatically created when viewing new weeks
- **Template-Based**: All schedules are generated from employee templates

### 3. Leave Request Integration
- **Automatic Updates**: Approved leave requests automatically update work schedules
- **Exchange Support**: Exchange off days automatically swap working/off status
- **Real-time Sync**: Changes are reflected immediately in the schedule

### 4. Enhanced Database Functions
- `get_or_create_work_schedule()`: Creates schedules from templates automatically
- `get_employee_day_status()`: Gets employee status for any date
- `update_schedule_for_approved_leave()`: Updates schedules when requests are approved
- `generate_week_schedules()`: Generates schedules for all employees for a week
- `get_available_coverage()`: Enhanced coverage detection using templates

## Database Schema

### New Tables

#### `work_schedule_templates`
```sql
CREATE TABLE work_schedule_templates (
  id BIGSERIAL PRIMARY KEY,
  employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
  monday_status VARCHAR(20) DEFAULT 'working',
  tuesday_status VARCHAR(20) DEFAULT 'working',
  wednesday_status VARCHAR(20) DEFAULT 'working',
  thursday_status VARCHAR(20) DEFAULT 'working',
  friday_status VARCHAR(20) DEFAULT 'working',
  saturday_status VARCHAR(20) DEFAULT 'off',
  sunday_status VARCHAR(20) DEFAULT 'off',
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(employee_id)
);
```

### New Functions

#### `get_or_create_work_schedule(employee_id, week_start_date)`
- Gets existing schedule or creates new one from template
- Automatically creates default template if none exists
- Returns schedule ID

#### `get_employee_day_status(employee_id, date)`
- Gets employee's working/off status for any specific date
- Automatically creates schedules from templates as needed
- Returns 'working' or 'off'

#### `update_schedule_for_approved_leave()`
- Trigger function that runs when requests are updated
- Automatically marks approved leave days as 'off'
- Handles exchange requests by swapping days

#### `generate_week_schedules(week_start_date)`
- Generates schedules for all employees for a specific week
- Uses templates to create default schedules
- Only creates schedules that don't already exist

## User Interface

### Admin Dashboard - Templates Tab
- **Template Table**: View and edit all employee templates
- **Day Toggle**: Click any day to toggle between working/off
- **Add Template**: Add templates for employees who don't have one
- **Generate Schedules**: Generate schedules for the current week
- **Remove Template**: Delete templates for employees

### Features
- **Visual Indicators**: Icons and colors for working/off days
- **Real-time Updates**: Changes save immediately
- **Bulk Operations**: Generate schedules for entire weeks
- **Employee Management**: Add/remove employees from templates

## How It Works

### 1. Template Creation
1. Admin creates templates for employees in the Templates tab
2. Each template defines default working/off days for the week
3. Templates are stored in the `work_schedule_templates` table

### 2. Schedule Generation
1. When viewing a week, the system checks if schedules exist
2. If no schedule exists, it's automatically created from the template
3. The `get_or_create_work_schedule()` function handles this process

### 3. Leave Request Integration
1. When a leave request is approved, the trigger function runs
2. The function updates the work schedule to mark leave days as 'off'
3. For exchange requests, it swaps the working/off status of the two days

### 4. Coverage Detection
1. The `get_available_coverage()` function uses templates to find available employees
2. It checks each employee's status for the requested date
3. Returns only employees who are marked as 'off' on that date

## Benefits

### For Admins
- **Reduced Manual Work**: Schedules are generated automatically
- **Consistency**: All schedules follow employee templates
- **Real-time Updates**: Changes reflect immediately
- **Bulk Management**: Manage multiple employees at once

### For Employees
- **Accurate Coverage**: Exchange requests only show truly available employees
- **Consistent Schedules**: Templates ensure predictable patterns
- **Automatic Updates**: Approved requests update schedules automatically

### For the System
- **Data Integrity**: All schedules are generated from templates
- **Performance**: Efficient database functions handle complex operations
- **Scalability**: System can handle any number of employees
- **Reliability**: Automatic creation prevents missing schedules

## Usage Instructions

### Setting Up Templates
1. Go to Admin Dashboard → Templates tab
2. Click "Add Template" for employees who need templates
3. Configure working/off days for each day of the week
4. Click on any day to toggle between working/off status

### Generating Schedules
1. In the Templates tab, click "Generate Week Schedules"
2. This creates schedules for the current week for all employees
3. Schedules are automatically created when viewing new weeks

### Managing Leave Requests
1. Approve leave requests as usual
2. The system automatically updates work schedules
3. Exchange requests automatically swap the working/off days

## Technical Notes

### Database Triggers
- `trigger_update_schedule_on_approval`: Runs when requests are updated
- `trigger_update_work_schedule_template_updated_at`: Updates timestamps

### Row Level Security
- Templates have RLS policies for employee access
- Admins can manage all templates
- Employees can view their own templates

### Performance Considerations
- Functions use efficient database operations
- Indexes are created for better performance
- Bulk operations minimize database calls

## Migration Notes

### For Existing Systems
1. Run the `work-schedule-automation.sql` script
2. Default templates are automatically created for existing employees
3. Existing schedules remain unchanged
4. New schedules will be generated from templates

### Data Integrity
- All existing data is preserved
- New automation features are additive
- Backward compatibility is maintained
- No breaking changes to existing functionality

## Future Enhancements

### Potential Features
- **Template Copying**: Copy templates between employees
- **Schedule Templates**: Different templates for different periods
- **Automated Notifications**: Notify when schedules are generated
- **Advanced Rules**: Complex scheduling rules and constraints
- **Calendar Integration**: Sync with external calendar systems

### Performance Optimizations
- **Caching**: Cache frequently accessed schedules
- **Batch Processing**: Process multiple weeks at once
- **Background Jobs**: Generate schedules in the background
- **Optimized Queries**: Further database query optimizations 