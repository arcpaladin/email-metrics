import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { RecentEmail } from '@/lib/types';

interface RecentEmailsProps {
  emails: RecentEmail[];
}

export function RecentEmails({ emails }: RecentEmailsProps) {
  const getSentimentBadge = (sentiment?: string, urgencyScore?: number) => {
    if (urgencyScore && urgencyScore >= 8) {
      return <Badge className="bg-red-100 text-red-800">Urgent</Badge>;
    }
    
    switch (sentiment) {
      case 'positive':
        return <Badge className="bg-green-100 text-green-800">Positive</Badge>;
      case 'negative':
        return <Badge className="bg-red-100 text-red-800">Negative</Badge>;
      default:
        return <Badge className="bg-gray-100 text-gray-800">Neutral</Badge>;
    }
  };

  const getPriorityIndicator = (urgencyScore?: number) => {
    if (!urgencyScore) return { color: 'bg-gray-500', label: 'Low' };
    if (urgencyScore >= 8) return { color: 'bg-red-500', label: 'High' };
    if (urgencyScore >= 5) return { color: 'bg-yellow-500', label: 'Medium' };
    return { color: 'bg-green-500', label: 'Low' };
  };

  const formatTimeAgo = (dateStr: string) => {
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    
    if (diffHours < 1) return 'Less than 1 hour ago';
    if (diffHours === 1) return '1 hour ago';
    if (diffHours < 24) return `${diffHours} hours ago`;
    
    const diffDays = Math.floor(diffHours / 24);
    if (diffDays === 1) return '1 day ago';
    return `${diffDays} days ago`;
  };

  return (
    <Card className="shadow-sm mb-8">
      <div className="p-6 border-b border-gray-200">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-semibold text-gray-900">Recent Email Analysis</h3>
          <Button variant="link" className="text-blue-500 hover:text-blue-600 p-0">
            View All
          </Button>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Sender</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Sentiment</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Received</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {emails.length === 0 ? (
              <tr>
                <td colSpan={5} className="px-6 py-8 text-center text-gray-500">
                  No emails found. Try syncing your emails to get started.
                </td>
              </tr>
            ) : (
              emails.map((email) => {
                const priority = getPriorityIndicator(email.analysis?.urgencyScore);
                return (
                  <tr key={email.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="flex-shrink-0 h-10 w-10">
                          <div className="h-10 w-10 rounded-full bg-blue-100 flex items-center justify-center">
                            <i className="fas fa-envelope text-blue-500"></i>
                          </div>
                        </div>
                        <div className="ml-4">
                          <div className="text-sm font-medium text-gray-900">
                            {email.subject || 'No Subject'}
                          </div>
                          <div className="text-sm text-gray-500 max-w-xs truncate">
                            {email.bodyPreview || 'No preview available'}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{email.sender.displayName || 'Unknown'}</div>
                      <div className="text-sm text-gray-500">{email.sender.email}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {getSentimentBadge(email.analysis?.sentiment, email.analysis?.urgencyScore)}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className={`w-2 h-2 ${priority.color} rounded-full mr-2`}></div>
                        <span className="text-sm text-gray-900">{priority.label}</span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {formatTimeAgo(email.receivedAt)}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
