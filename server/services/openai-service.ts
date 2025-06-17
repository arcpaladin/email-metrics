import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

export interface TaskExtractionResult {
  tasks: Array<{
    title: string;
    description: string;
    assignedTo?: string;
    dueDate?: string;
    priority: 'high' | 'medium' | 'low';
    category: 'meeting' | 'review' | 'deliverable' | 'follow-up' | 'research';
    confidence: number;
  }>;
  summary: string;
  sentiment: 'positive' | 'negative' | 'neutral' | 'urgent';
  urgencyScore: number;
  keyTopics: string[];
  actionRequired: boolean;
}

export interface SentimentResult {
  sentiment: 'positive' | 'negative' | 'neutral';
  urgencyScore: number;
  emotions: string[];
  confidence: number;
}

export class AIAnalysisService {
  async extractTasks(emailContent: string, context: {
    subject: string;
    sender: string;
    recipients: string[];
  }): Promise<TaskExtractionResult> {
    const prompt = `
Analyze the following email and extract actionable tasks. Consider the context and relationships between sender and recipients.

Email Subject: ${context.subject}
From: ${context.sender}
To: ${context.recipients.join(', ')}

Email Content:
${emailContent}

Extract tasks in this JSON format:
{
  "tasks": [
    {
      "title": "Brief task description",
      "description": "Detailed explanation",
      "assignedTo": "email@domain.com or null",
      "dueDate": "ISO date or null",
      "priority": "high|medium|low",
      "category": "meeting|review|deliverable|follow-up|research",
      "confidence": 0.85
    }
  ],
  "summary": "Overall email purpose",
  "sentiment": "positive|negative|neutral|urgent",
  "urgencyScore": 5,
  "keyTopics": ["topic1", "topic2"],
  "actionRequired": true
}

Only extract explicit or strongly implied tasks. Be conservative with confidence scores.
    `;

    try {
      const response = await openai.chat.completions.create({
        model: 'gpt-4o', // the newest OpenAI model is "gpt-4o" which was released May 13, 2024. do not change this unless explicitly requested by the user
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.3,
        max_tokens: 1000,
        response_format: { type: "json_object" },
      });

      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error('No response from OpenAI');

      return JSON.parse(content);
    } catch (error) {
      console.error('AI analysis error:', error);
      throw error;
    }
  }

  async analyzeSentiment(text: string): Promise<SentimentResult> {
    const prompt = `
Analyze the sentiment and urgency of this text:

"${text}"

Respond with JSON:
{
  "sentiment": "positive|negative|neutral",
  "urgencyScore": 1-10,
  "emotions": ["confused", "frustrated", "excited"],
  "confidence": 0.85
}
    `;

    try {
      const response = await openai.chat.completions.create({
        model: 'gpt-4o', // the newest OpenAI model is "gpt-4o" which was released May 13, 2024. do not change this unless explicitly requested by the user
        messages: [{ role: 'user', content: prompt }],
        temperature: 0.2,
        max_tokens: 200,
        response_format: { type: "json_object" },
      });

      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error('No response from OpenAI');

      return JSON.parse(content);
    } catch (error) {
      console.error('Sentiment analysis error:', error);
      throw error;
    }
  }
}
