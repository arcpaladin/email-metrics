import { Card, CardContent } from '@/components/ui/card';
import { DashboardMetrics } from '@/lib/types';

interface MetricsOverviewProps {
  metrics: DashboardMetrics;
}

export function MetricsOverview({ metrics }: MetricsOverviewProps) {
  const metricCards = [
    {
      title: 'Total Emails',
      value: metrics.totalEmails.toLocaleString(),
      change: 12.5,
      icon: 'fas fa-envelope',
      color: 'bg-blue-100 text-blue-500'
    },
    {
      title: 'Tasks Identified',
      value: metrics.tasksIdentified.toString(),
      change: 8.2,
      icon: 'fas fa-tasks',
      color: 'bg-yellow-100 text-yellow-600'
    },
    {
      title: 'Avg Response Time',
      value: metrics.avgResponseTime,
      change: -18,
      icon: 'fas fa-clock',
      color: 'bg-green-100 text-green-500'
    },
    {
      title: 'Team Productivity',
      value: `${metrics.productivity}%`,
      change: 5.3,
      icon: 'fas fa-chart-line',
      color: 'bg-purple-100 text-purple-500'
    }
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      {metricCards.map((metric, index) => (
        <Card key={index} className="shadow-sm">
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">{metric.title}</p>
                <p className="text-3xl font-bold text-gray-900 mt-2">{metric.value}</p>
                <div className="flex items-center mt-2">
                  <i className={`fas ${metric.change >= 0 ? 'fa-arrow-up text-green-500' : 'fa-arrow-down text-red-500'} text-sm mr-1`}></i>
                  <span className={`text-sm font-medium ${metric.change >= 0 ? 'text-green-500' : 'text-red-500'}`}>
                    {Math.abs(metric.change)}% vs last week
                  </span>
                </div>
              </div>
              <div className={`w-12 h-12 ${metric.color} rounded-xl flex items-center justify-center`}>
                <i className={`${metric.icon} text-xl`}></i>
              </div>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
