import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import AdminDashboard from './components/AdminDashboard';
import EmployeePortal from './components/EmployeePortal';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Navigate to="/employee" replace />} />
        <Route path="/admin" element={<AdminDashboard />} />
        <Route path="/employee" element={<EmployeePortal />} />
      </Routes>
    </Router>
  );
}

export default App; 