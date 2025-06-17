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
    const currentUser = AuthManager.getUser();
    setUser(currentUser);
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
      // Get fresh access token
      const msalResult = await MSALService.signIn();
      
      // Sync emails
      const response = await apiRequest('POST', '/api/emails/sync', {
        accessToken: msalResult.accessToken
      });
      
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
    } catch (error) {
      console.error('Sync error:', error);
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
              <Button 
                onClick={handleSyncEmails}
                disabled={isSyncing}
                className="bg-blue-500 hover:bg-blue-600 text-white"
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
            </div>
          </div>
        </header>

        <div className="p-6">
          {/* Metrics Overview */}
          {metrics && <MetricsOverview metrics={metrics} />}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            {/* Email Volume Chart */}
            {volumeData && <EmailVolumeChart data={volumeData} />}
            
            {/* Sentiment Analysis */}
            {sentimentData && <SentimentAnalysis data={sentimentData} />}
          </div>

          {/* Recent Emails */}
          {recentEmails && <RecentEmails emails={recentEmails} />}

          {/* Task Management & Team Performance */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {recentTasks && (
              <TaskManagement 
                tasks={recentTasks} 
                onTaskUpdate={handleTaskUpdate}
              />
            )}
            {teamMembers && <TeamPerformance teamMembers={teamMembers} />}
          </div>
        </div>
      </main>
    </div>
  );
}
