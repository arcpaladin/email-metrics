import { Card, CardContent } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { EmailVolumeData } from '@/lib/types';
import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { AuthManager } from '@/lib/auth';

interface EmailVolumeChartProps {
  data: EmailVolumeData[];
}

export function EmailVolumeChart({ data: initialData }: EmailVolumeChartProps) {
  const [period, setPeriod] = useState('7');

  const { data: volumeData } = useQuery<EmailVolumeData[]>({
    queryKey: ['/api/dashboard/email-volume', period],
    queryFn: async () => {
      const response = await fetch(`/api/dashboard/email-volume?days=${period}`, {
        headers: {
          ...AuthManager.getAuthHeaders(),
        },
      });
      if (!response.ok) throw new Error('Failed to fetch volume data');
      return response.json();
    },
  });

  const data = volumeData || initialData;

  const formatDate = (dateStr: string) => {
    const date = new Date(dateStr);
    const days = parseInt(period);
    
    if (days <= 7) {
      return date.toLocaleDateString('en-US', { weekday: 'short' });
    } else if (days <= 30) {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    } else {
      return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    }
  };

  const chartData = data.map(item => ({
    ...item,
    day: formatDate(item.date),
    count: parseInt(item.count.toString())
  }));

  return (
    <Card className="shadow-sm">
      <CardContent className="p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">Email Volume Trends</h3>
          <Select value={period} onValueChange={setPeriod}>
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="7">Last 7 days</SelectItem>
              <SelectItem value="30">Last 30 days</SelectItem>
              <SelectItem value="90">Last 90 days</SelectItem>
            </SelectContent>
          </Select>
        </div>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="day" />
              <YAxis />
              <Tooltip 
                formatter={(value) => [value, 'Emails']}
                labelFormatter={(label) => `Day: ${label}`}
              />
              <Bar dataKey="count" fill="hsl(207, 90%, 54%)" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </CardContent>
    </Card>
  );
}
