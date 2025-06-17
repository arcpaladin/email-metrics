import { Card, CardContent } from '@/components/ui/card';
import { SentimentData } from '@/lib/types';

interface SentimentAnalysisProps {
  data: SentimentData;
}

export function SentimentAnalysis({ data }: SentimentAnalysisProps) {
  const total = data.positive + data.neutral + data.negative;
  
  const sentimentItems = [
    {
      label: 'Positive',
      count: data.positive,
      percentage: total > 0 ? Math.round((data.positive / total) * 100) : 0,
      color: 'bg-green-500',
      bgColor: 'bg-green-100',
      textColor: 'text-green-800'
    },
    {
      label: 'Neutral',
      count: data.neutral,
      percentage: total > 0 ? Math.round((data.neutral / total) * 100) : 0,
      color: 'bg-gray-400',
      bgColor: 'bg-gray-100',
      textColor: 'text-gray-800'
    },
    {
      label: 'Negative',
      count: data.negative,
      percentage: total > 0 ? Math.round((data.negative / total) * 100) : 0,
      color: 'bg-red-500',
      bgColor: 'bg-red-100',
      textColor: 'text-red-800'
    }
  ];

  return (
    <Card className="shadow-sm">
      <CardContent className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-6">Email Sentiment Analysis</h3>
        <div className="space-y-4">
          {sentimentItems.map((item) => (
            <div key={item.label} className="flex items-center justify-between">
              <div className="flex items-center">
                <div className={`w-4 h-4 ${item.color} rounded mr-3`}></div>
                <span className="text-sm font-medium text-gray-700">{item.label}</span>
              </div>
              <div className="flex items-center">
                <span className="text-sm font-semibold text-gray-900 mr-2">{item.percentage}%</span>
                <div className="w-24 h-2 bg-gray-200 rounded overflow-hidden">
                  <div 
                    className={`h-full ${item.color}`}
                    style={{ width: `${item.percentage}%` }}
                  ></div>
                </div>
              </div>
            </div>
          ))}
        </div>
        {total > 0 && (
          <div className="mt-6 p-4 bg-blue-50 rounded-lg">
            <p className="text-sm text-blue-800">
              <i className="fas fa-info-circle mr-2"></i>
              Overall sentiment analysis based on {total} analyzed emails.
            </p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
