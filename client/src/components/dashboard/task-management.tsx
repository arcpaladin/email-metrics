import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { RecentTask } from '@/lib/types';
import { apiRequest } from '@/lib/queryClient';
import { AuthManager } from '@/lib/auth';
import { useToast } from '@/hooks/use-toast';

interface TaskManagementProps {
  tasks: RecentTask[];
  onTaskUpdate: () => void;
}

export function TaskManagement({ tasks, onTaskUpdate }: TaskManagementProps) {
  const { toast } = useToast();

  const handleTaskAction = async (taskId: number, action: 'approve' | 'reject') => {
    try {
      const status = action === 'approve' ? 'in_progress' : 'completed';
      
      await apiRequest('PUT', `/api/tasks/${taskId}/status`, {
        status,
      });

      toast({
        title: action === 'approve' ? 'Task Approved' : 'Task Rejected',
        description: `Task has been ${action === 'approve' ? 'moved to in progress' : 'marked as completed'}.`,
      });

      onTaskUpdate();
    } catch (error) {
      console.error('Task action error:', error);
      toast({
        title: 'Error',
        description: 'Failed to update task status.',
        variant: 'destructive',
      });
    }
  };

  const getPriorityBadge = (priority?: string) => {
    switch (priority) {
      case 'high':
        return <Badge className="bg-red-100 text-red-800">High Priority</Badge>;
      case 'medium':
        return <Badge className="bg-yellow-100 text-yellow-800">Medium Priority</Badge>;
      case 'low':
        return <Badge className="bg-green-100 text-green-800">Low Priority</Badge>;
      default:
        return <Badge className="bg-gray-100 text-gray-800">Unknown Priority</Badge>;
    }
  };

  const formatDueDate = (dueDateStr?: string) => {
    if (!dueDateStr) return 'No due date';
    
    const dueDate = new Date(dueDateStr);
    const now = new Date();
    const diffMs = dueDate.getTime() - now.getTime();
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffDays < 0) return 'Overdue';
    if (diffDays === 0) return 'Due today';
    if (diffDays === 1) return 'Due tomorrow';
    if (diffDays <= 7) return `Due in ${diffDays} days`;
    return dueDate.toLocaleDateString();
  };

  return (
    <Card className="shadow-sm">
      <CardContent className="p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">AI-Generated Tasks</h3>
          <Badge className="bg-green-100 text-green-800">
            <i className="fas fa-robot mr-1"></i>
            AI Powered
          </Badge>
        </div>
        <div className="space-y-4">
          {tasks.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <i className="fas fa-tasks text-3xl mb-4"></i>
              <p>No tasks identified yet.</p>
              <p className="text-sm">Sync your emails to let AI extract tasks automatically.</p>
            </div>
          ) : (
            tasks.map((task) => (
              <div key={task.id} className="border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-all">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <h4 className="font-medium text-gray-900 mb-1">{task.title}</h4>
                    <p className="text-sm text-gray-600 mb-3">
                      Extracted from: "{task.sourceEmail?.subject || 'Unknown email'}"
                    </p>
                    <div className="flex items-center space-x-4 flex-wrap gap-2">
                      {getPriorityBadge(task.priority)}
                      <span className="text-xs text-gray-500">
                        {formatDueDate(task.dueDate)}
                      </span>
                      {task.confidenceScore && (
                        <span className="text-xs text-gray-500">
                          Confidence: {Math.round(task.confidenceScore * 100)}%
                        </span>
                      )}
                    </div>
                  </div>
                  <div className="flex items-center space-x-2 ml-4">
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleTaskAction(task.id, 'approve')}
                      className="text-green-500 hover:text-green-600 hover:bg-green-50"
                    >
                      <i className="fas fa-check"></i>
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      onClick={() => handleTaskAction(task.id, 'reject')}
                      className="text-red-500 hover:text-red-600 hover:bg-red-50"
                    >
                      <i className="fas fa-times"></i>
                    </Button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </CardContent>
    </Card>
  );
}
