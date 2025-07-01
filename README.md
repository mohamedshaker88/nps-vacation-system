# NPS Team Vacation Management System

A comprehensive vacation management system built with React, Vite, Tailwind CSS, and Supabase for the NPS Team.

## 🚀 **Production Deployment**

- **Main Application**: https://vaccation-management-system-9dvty3ma7.vercel.app
- **Admin Portal**: https://vaccation-management-system-9dvty3ma7.vercel.app/admin
- **Employee Portal**: https://vaccation-management-system-9dvty3ma7.vercel.app/employee

## 🔐 **Access Credentials**

### Admin Portal
- **Username**: `admin`
- **Password**: `NPSTEAM!`

### Employee Portal
- Use registered employee email and password
- Default test employee: `john.doe@technetworkinc.com` / `password123`

## ✨ **Features**

### **Admin Dashboard**
- **Dashboard Overview**: Real-time statistics and recent requests
- **Employee Management**:
  - ✅ Create new employees
  - ✅ Edit existing employee details (name, email, phone)
  - ✅ Delete employees with confirmation
  - ✅ Manage vacation balances (annual & sick leave)
- **Request Management**: Approve/reject leave requests
- **Policy Management**: View company leave policies and guidelines

### **Employee Portal**
- Submit leave requests
- View request history and status
- Check remaining vacation days
- Update personal information

## 🛠 **Technology Stack**

- **Frontend**: React 18 + Vite
- **Styling**: Tailwind CSS
- **Database**: Supabase (PostgreSQL)
- **Deployment**: Vercel
- **Icons**: Lucide React
- **State Management**: React Hooks

## 📊 **Database Schema**

### Employees Table
```sql
- id (BIGSERIAL PRIMARY KEY)
- name (VARCHAR)
- email (VARCHAR UNIQUE)
- phone (VARCHAR)
- password (VARCHAR)
- annual_leave_remaining (INTEGER DEFAULT 15)
- sick_leave_remaining (INTEGER DEFAULT 10)
- created_at (TIMESTAMP)
```

### Requests Table
```sql
- id (BIGSERIAL PRIMARY KEY)
- employee_name (VARCHAR)
- employee_email (VARCHAR)
- type (VARCHAR)
- start_date (DATE)
- end_date (DATE)
- days (INTEGER)
- reason (TEXT)
- status (VARCHAR DEFAULT 'Pending')
- submit_date (DATE)
- coverage_arranged (BOOLEAN)
- coverage_by (VARCHAR)
- emergency_contact (VARCHAR)
- additional_notes (TEXT)
- medical_certificate (BOOLEAN)
- created_at (TIMESTAMP)
```

## 🏢 **Leave Policy**

### **Paid Leave**
- **Annual Leave**: 15 days per year
- **Sick Leave**: 10 days per year (1 day max per request)

### **Unpaid Leave**
- Emergency Leave: 3 days per incident
- Personal Days: As needed
- Maternity Leave: 70 days
- Paternity Leave: 7 days
- Bereavement Leave: 5 days per incident
- Religious Leave: 2 days
- Compensatory Time: 3 days
- Unpaid Leave: Up to 30 days

## 🔧 **Setup Instructions**

### **For Development**
1. Clone the repository
2. Install dependencies: `npm install`
3. Set up environment variables (see below)
4. Run development server: `npm run dev`

### **Environment Variables**
Create a `.env` file with:
```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### **Database Setup**
1. Create a Supabase project
2. Run the `supabase-setup.sql` script in Supabase SQL Editor
3. For existing databases, run `migration-add-vacation-balance.sql`

## 📱 **Usage Guide**

### **Admin Operations**
1. **Create Employee**: Click "Add Employee" → Fill form → Create
2. **Edit Employee**: Click edit icon → Modify fields → Save
3. **Delete Employee**: Click delete icon → Confirm deletion
4. **Manage Vacation**: Click calendar icon → Update days → Save
5. **Approve Requests**: View requests → Click Approve/Reject

### **Employee Operations**
1. **Submit Request**: Fill request form → Submit
2. **Check Status**: View request history
3. **Update Profile**: Modify personal information

## 🔒 **Security Features**

- Row Level Security (RLS) enabled
- Admin policies for full access
- Employee policies for own data only
- Password protection for all accounts
- Confirmation dialogs for destructive actions

## 📈 **Performance**

- Optimized database queries with indexes
- Lazy loading of components
- Efficient state management
- Responsive design for all devices

## 🚨 **Important Notes**

- **24/7 Coverage**: System designed for 5pm-1am daily operations
- **Minimum Staff**: 8 staff members must be available
- **Coverage Requirements**: All leave requests require coverage arrangements
- **Peak Periods**: 4 weeks advance notice for holidays
- **Maximum Concurrent Leave**: 3 people maximum

## 🆘 **Support**

For technical issues or questions:
1. Check browser console for error messages
2. Verify database connection and permissions
3. Ensure environment variables are correctly set
4. Contact system administrator

## 📝 **Version History**

- **v1.0.0**: Initial release with basic functionality
- **v1.1.0**: Added comprehensive employee management
- **v1.2.0**: Added vacation balance management
- **v1.3.0**: Production-ready with full CRUD operations

---

**Built for NPS Team** | **Vacation Management System** | **Production Ready** ✅ 