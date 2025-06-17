import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Sidebar } from '@/components/layout/sidebar';
import { AuthManager } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useToast } from '@/hooks/use-toast';
import { MSALService } from '@/lib/auth';
import { apiRequest } from '@/lib/queryClient';
import type { RecentEmail } from '@/lib/types';
import { RefreshCw, Mail, Clock, TrendingUp } from 'lucide-react';

export default function Emails() {
  const user = AuthManager.getUser();
  const [isSyncing, setIsSyncing] = useState(false);
  const { toast } = useToast();

  const { data: emails = [], refetch: refetchEmails } = useQuery<RecentEmail[]>({
    queryKey: ['/api/emails/recent'],
  });

  if (!user) {
    return <div>Please log in to access this page.</div>;
  }

  const handleSyncEmails = async () => {
    setIsSyncing(true);
    try {
      const msalResult = await MSALService.signIn();
      const response = await apiRequest('POST', '/api/emails/sync', {
        accessToken: msalResult.accessToken
      });
      
      const data = await response.json();
      
      toast({
        title: "Email Sync Complete",
        description: `Synced ${data.emailsSynced} emails and identified ${data.tasksCreated} tasks.`,
      });
      
      refetchEmails();
    } catch (error: any) {
      console.error('Email sync error:', error);
      toast({
        title: "Sync Failed",
        description: error.message || "Failed to sync emails. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsSyncing(false);
    }
  };

  const getSentimentColor = (sentiment?: string) => {
    switch (sentiment) {
      case 'positive': return 'bg-green-100 text-green-800';
      case 'negative': return 'bg-red-100 text-red-800';
      case 'urgent': return 'bg-orange-100 text-orange-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  const getUrgencyColor = (score?: number) => {
    if (!score) return 'bg-gray-100 text-gray-800';
    if (score >= 0.8) return 'bg-red-100 text-red-800';
    if (score >= 0.6) return 'bg-orange-100 text-orange-800';
    if (score >= 0.4) return 'bg-yellow-100 text-yellow-800';
    return 'bg-green-100 text-green-800';
  };

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar user={user} />
      
      <main className="flex-1 overflow-auto">
        <div className="p-6">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">Email Analysis</h1>
              <p className="text-gray-600">Manage and analyze your email communications</p>
            </div>
            <Button 
              onClick={handleSyncEmails} 
              disabled={isSyncing}
              className="flex items-center gap-2"
            >
              <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
              {isSyncing ? 'Syncing...' : 'Sync Emails'}
            </Button>
          </div>

          <div className="grid gap-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Mail className="w-5 h-5" />
                  Recent Emails ({emails.length})
                </CardTitle>
              </CardHeader>
              <CardContent>
                {emails.length === 0 ? (
                  <div className="text-center py-8 text-gray-500">
                    <Mail className="w-12 h-12 mx-auto mb-4 opacity-50" />
                    <p>No emails found. Click "Sync Emails" to import from Microsoft Graph.</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {emails.map((email) => (
                      <div key={email.id} className="border rounded-lg p-4 hover:bg-gray-50">
                        <div className="flex items-start justify-between mb-2">
                          <div className="flex-1">
                            <h3 className="font-medium text-gray-900">
                              {email.subject || 'No Subject'}
                            </h3>
                            <p className="text-sm text-gray-600">
                              From: {email.sender.displayName || email.sender.email}
                            </p>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-gray-500">
                            <Clock className="w-4 h-4" />
                            {new Date(email.receivedAt).toLocaleDateString()}
                          </div>
                        </div>
                        
                        {email.bodyPreview && (
                          <p className="text-sm text-gray-700 mb-3 line-clamp-2">
                            {email.bodyPreview}
                          </p>
                        )}
                        
                        {email.analysis && (
                          <div className="flex items-center gap-2">
                            {email.analysis.sentiment && (
                              <Badge className={getSentimentColor(email.analysis.sentiment)}>
                                {email.analysis.sentiment}
                              </Badge>
                            )}
                            {email.analysis.urgencyScore !== undefined && (
                              <Badge className={getUrgencyColor(email.analysis.urgencyScore)}>
                                <TrendingUp className="w-3 h-3 mr-1" />
                                Urgency: {Math.round(email.analysis.urgencyScore * 100)}%
                              </Badge>
                            )}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </main>
    </div>
  );
}