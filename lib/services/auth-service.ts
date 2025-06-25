import jwt from 'jsonwebtoken';
import { storage } from '../storage';
import type { Employee } from '../../shared/schema';

const JWT_SECRET = process.env.JWT_SECRET || 'your-jwt-secret-key';

export interface AuthUser {
  id: number;
  email: string;
  displayName?: string;
  role?: string;
  organizationId?: number;
}

export class AuthService {
  generateToken(user: AuthUser): string {
    return jwt.sign(user, JWT_SECRET, { expiresIn: '24h' });
  }

  verifyToken(token: string): AuthUser | null {
    try {
      return jwt.verify(token, JWT_SECRET) as AuthUser;
    } catch (error) {
      return null;
    }
  }

  async authenticateEmployee(email: string): Promise<{ token: string; user: AuthUser } | null> {
    const employee = await storage.getEmployeeByEmail(email);
    if (!employee) {
      return null;
    }

    const user: AuthUser = {
      id: employee.id,
      email: employee.email,
      displayName: employee.displayName || undefined,
      role: employee.role || undefined,
      organizationId: employee.organizationId || undefined,
    };

    const token = this.generateToken(user);
    return { token, user };
  }

  async createEmployeeFromGraph(graphUser: any, organizationId: number): Promise<Employee> {
    const employee = await storage.createEmployee({
      organizationId,
      email: graphUser.mail,
      displayName: graphUser.displayName,
      department: graphUser.department,
      role: graphUser.jobTitle,
    });

    return employee;
  }
}

export const authService = new AuthService();
