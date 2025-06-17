import { Card, CardContent } from '@/components/ui/card';
import { TeamMember } from '@/lib/types';

interface TeamPerformanceProps {
  teamMembers: TeamMember[];
}

export function TeamPerformance({ teamMembers }: TeamPerformanceProps) {
  const getInitials = (name?: string, email?: string) => {
    if (name) {
      return name.split(' ').map(n => n.charAt(0)).join('').toUpperCase();
    }
    return email?.charAt(0).toUpperCase() || '?';
  };

  const getGradientColor = (index: number) => {
    const colors = [
      'from-blue-400 to-blue-600',
      'from-green-400 to-green-600',
      'from-purple-400 to-purple-600',
      'from-red-400 to-red-600',
      'from-yellow-400 to-yellow-600',
      'from-indigo-400 to-indigo-600',
    ];
    return colors[index % colors.length];
  };

  // Mock performance scores - in a real app, this would come from analytics
  const getPerformanceScore = () => {
    return Math.floor(Math.random() * 30) + 70; // Random score between 70-100
  };

  const teamWithScores = teamMembers.map((member, index) => ({
    ...member,
    performanceScore: getPerformanceScore(),
    gradient: getGradientColor(index)
  }));

  const averageScore = teamWithScores.length > 0 
    ? Math.round(teamWithScores.reduce((sum, member) => sum + member.performanceScore, 0) / teamWithScores.length)
    : 0;

  return (
    <Card className="shadow-sm">
      <CardContent className="p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-6">Team Performance</h3>
        <div className="space-y-6">
          {teamWithScores.length === 0 ? (
            <div className="text-center py-8 text-gray-500">
              <i className="fas fa-users text-3xl mb-4"></i>
              <p>No team members found.</p>
            </div>
          ) : (
            teamWithScores.map((member) => (
              <div key={member.id} className="flex items-center justify-between">
                <div className="flex items-center">
                  <div className={`w-10 h-10 bg-gradient-to-br ${member.gradient} rounded-full flex items-center justify-center`}>
                    <span className="text-white font-medium text-sm">
                      {getInitials(member.displayName, member.email)}
                    </span>
                  </div>
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">
                      {member.displayName || member.email}
                    </p>
                    <p className="text-xs text-gray-500">
                      {member.role || member.department || 'Employee'}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="text-sm font-semibold text-gray-900">{member.performanceScore}%</p>
                  <div className="w-16 h-1.5 bg-gray-200 rounded mt-1">
                    <div 
                      className={`h-full rounded ${
                        member.performanceScore >= 90 ? 'bg-green-500' :
                        member.performanceScore >= 75 ? 'bg-yellow-500' : 'bg-red-500'
                      }`}
                      style={{ width: `${member.performanceScore}%` }}
                    ></div>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
        {teamWithScores.length > 0 && (
          <div className="mt-6 pt-4 border-t border-gray-200">
            <div className="flex items-center justify-between">
              <p className="text-sm text-gray-600">Team Average</p>
              <p className="text-sm font-semibold text-gray-900">{averageScore}%</p>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
