import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { Sidebar } from '@/components/layout/sidebar';
import { MetricsOverview } from '@/components/dashboard/metrics-overview';
import { EmailVolumeChart } from '@/components/dashboard/email-volume-chart';
import { SentimentAnalysis } from '@/components/dashboard/sentiment-analysis';
import { RecentEmails } from '@/components/dashboard/recent-emails';
import { TaskManagement } from '@/components/dashboard/task-management';
import { TeamPerformance } from '@/components/dashboard/team-performance';
import { AuthManager, MSALService } from '@/lib/auth';
import { apiRequest } from '@/lib/queryClient';
import type { 
  DashboardMetrics, 
  SentimentData, 
  EmailVolumeData, 
  RecentEmail, 
  RecentTask, 
  TeamMember,
  AuthUser 
} from '@/lib/types';

export default function Dashboard() {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);
  const { toast } = useToast();

  useEffect(() => {
    // Check for authentication immediately and clear invalid state
    const checkAuth = () => {
      const currentUser = AuthManager.getUser();
      const token = AuthManager.getToken();
      
      // If we detect any authentication issues, clear everything
      if ((currentUser && !token) || (!currentUser && token) || !currentUser || !token) {
        console.log('Authentication issue detected, clearing all local storage');
        localStorage.clear();
        sessionStorage.clear();
        
        // Clear cookies if any
        document.cookie.split(";").forEach(function(c) { 
          document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); 
        });
        
        // Force redirect to login
        window.location.replace('/login');
        return;
      }
      
      setUser(currentUser);
    };
    
    checkAuth();
  }, []);

  // Data queries
  const { data: metrics, refetch: refetchMetrics } = useQuery<DashboardMetrics>({
    queryKey: ['/api/dashboard/metrics'],
    enabled: !!user,
  });

  const { data: sentimentData, refetch: refetchSentiment } = useQuery<SentimentData>({
    queryKey: ['/api/dashboard/sentiment'],
    enabled: !!user,
  });

  const { data: volumeData, refetch: refetchVolume } = useQuery<EmailVolumeData[]>({
    queryKey: ['/api/dashboard/email-volume'],
    enabled: !!user,
  });

  const { data: recentEmails, refetch: refetchEmails } = useQuery<RecentEmail[]>({
    queryKey: ['/api/emails/recent'],
    enabled: !!user,
  });

  const { data: recentTasks, refetch: refetchTasks } = useQuery<RecentTask[]>({
    queryKey: ['/api/tasks/recent'],
    enabled: !!user,
  });

  const { data: teamMembers, refetch: refetchTeam } = useQuery<TeamMember[]>({
    queryKey: ['/api/employees/team'],
    enabled: !!user,
  });

  const handleSyncEmails = async () => {
    if (!user) return;
    
    setIsSyncing(true);
    try {
      // Check authentication first
      if (!AuthManager.isAuthenticated()) {
        toast({
          title: "Authentication Required",
          description: "Please sign in with Microsoft first.",
          variant: "destructive",
        });
        AuthManager.logout();
        window.location.href = '/login';
        return;
      }

      // Get fresh access token
      const msalResult = await MSALService.signIn();
      
      // Sync emails
      const response = await apiRequest('POST', '/api/emails/sync', {
        accessToken: msalResult.accessToken
      });
      
      if (!response.ok) {
        if (response.status === 401 || response.status === 403) {
          toast({
            title: "Authentication Expired",
            description: "Your Microsoft login has expired. Please sign in again.",
            variant: "destructive",
          });
          AuthManager.logout();
          window.location.href = '/login';
          return;
        }
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const result = await response.json();
      
      toast({
        title: "Sync Complete!",
        description: `Processed ${result.processedCount} new emails out of ${result.totalFetched} fetched.`,
      });

      // Refresh all data
      refetchMetrics();
      refetchEmails();
      refetchTasks();
      refetchSentiment();
      refetchVolume();
    } catch (error: any) {
      console.error('Sync error:', error);
      
      if (error.message?.includes('401') || error.message?.includes('403')) {
        toast({
          title: "Authentication Failed",
          description: "Please sign in again with Microsoft.",
          variant: "destructive",
        });
        AuthManager.logout();
        window.location.href = '/login';
        return;
      }
      
      toast({
        title: "Sync Failed",
        description: "Failed to sync emails. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsSyncing(false);
    }
  };

  const handleTaskUpdate = () => {
    refetchTasks();
    refetchMetrics();
  };

  if (!user) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar user={user} />
      
      <main className="flex-1 overflow-y-auto">
        {/* Header */}
        <header className="bg-white border-b border-gray-200 px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-2xl font-semibold text-gray-900">Dashboard</h1>
              <p className="text-sm text-gray-600 mt-1">
                Welcome back, {user.displayName?.split(' ')[0] || user.email}! Here's what's happening with your team's email activity.
              </p>
            </div>
            <div className="flex items-center space-x-4">
              <div className="relative">
                <Button variant="ghost" size="sm" className="relative">
                  <i className="fas fa-bell text-xl"></i>
                  <span className="absolute -top-1 -right-1 w-5 h-5 bg-red-500 text-white text-xs rounded-full flex items-center justify-center">
                    3
                  </span>
                </Button>
              </div>
              {!AuthManager.isAuthenticated() && (
                <Button 
                  onClick={() => {
                    AuthManager.logout();
                    window.location.href = '/login';
                  }}
                  variant="outline"
                  className="border-red-200 text-red-600 hover:bg-red-50"
                >
                  <i className="fas fa-exclamation-triangle mr-2"></i>
                  Fix Authentication
                </Button>
              )}
              <Button 
                onClick={handleSyncEmails}
                disabled={isSyncing || !AuthManager.isAuthenticated()}
                className="bg-blue-500 hover:bg-blue-600 text-white disabled:bg-gray-400"
              >
                {isSyncing ? (
                  <>
                    <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
                    Syncing...
                  </>
                ) : (
                  <>
                    <i className="fas fa-sync-alt mr-2"></i>
                    Sync Emails
                  </>
                )}
              </Button>
              <Button 
                onClick={() => {
                  AuthManager.logout();
                  localStorage.clear();
                  sessionStorage.clear();
                  window.location.href = '/login';
                }}
                variant="outline"
                className="border-gray-300 text-gray-700 hover:bg-gray-50"
              >
                <i className="fas fa-sign-out-alt mr-2"></i>
                Sign Out
              </Button>
            </div>
          </div>
        </header>

        <div className="p-6 space-y-6">
          {/* Metrics Overview */}
          {metrics && <MetricsOverview metrics={metrics} />}

          {/* Email Analytics Section */}
          <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
            {/* Email Volume Chart - Takes 2 columns */}
            <div className="xl:col-span-2">
              {volumeData && <EmailVolumeChart data={volumeData} />}
            </div>
            
            {/* Sentiment Analysis - Takes 1 column */}
            <div className="xl:col-span-1">
              {sentimentData && <SentimentAnalysis data={sentimentData} />}
            </div>
          </div>

          {/* Recent Activity Section */}
          <div className="grid grid-cols-1 xl:grid-cols-3 gap-6">
            {/* Recent Emails - Takes 2 columns */}
            <div className="xl:col-span-2">
              {recentEmails && <RecentEmails emails={recentEmails} />}
            </div>
            
            {/* Task Management - Takes 1 column */}
            <div className="xl:col-span-1">
              {recentTasks && (
                <TaskManagement 
                  tasks={recentTasks} 
                  onTaskUpdate={handleTaskUpdate}
                />
              )}
            </div>
          </div>

          {/* Team Performance Section */}
          <div className="w-full">
            {teamMembers && <TeamPerformance teamMembers={teamMembers} />}
          </div>
        </div>
      </main>
    </div>
  );
}
