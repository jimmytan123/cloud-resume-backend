import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

// Initialize DynamoDB DocumentClient
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

const snsClient = new SNSClient({});

// Constants
const TABLE_NAME = 'Cloud_Resume';
const PAGE_ID = '1'; // Fixed key for the single page

// Milestones to trigger notifications
const milestones = [140, 200, 300, 400, 500, 1000];

// Handler function
export const handler = async (event, context) => {
  // Params for updating the database
  const input = {
    TableName: TABLE_NAME,
    Key: {
      PageId: PAGE_ID,
    },
    UpdateExpression:
      'SET ViewCount = if_not_exists(ViewCount, :startValue) + :incrementValue',
    ExpressionAttributeValues: {
      ':startValue': 0, // Initialize count if it doesn't exist
      ':incrementValue': 1,
    },
    ReturnValues: 'ALL_NEW',
  };

  // Determine configs for CORS
  const allowedOrigins = ['http://localhost:5173', 'https://resume.jimtan.ca'];
  const origin = event.headers?.origin;
  const corsOrigin = allowedOrigins.includes(origin)
    ? origin
    : 'https://resume.jimtan.ca'; // Default to production

  try {
    const response = await docClient.send(new UpdateCommand(input));

    const viewCount = response.Attributes.ViewCount;

    // Check threshold and publish to SNS if exceeded
    if (milestones.includes(viewCount)) {
      const message = `Congrats! Your resume has been viewed ${viewCount} times!`;

      await snsClient.send(
        new PublishCommand({
          TopicArn: process.env.SNS_TOPIC_ARN,
          Message: message,
          Subject: 'Cloud Resume View Count Milestone',
        })
      );
    }

    return {
      statusCode: 201,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': corsOrigin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      body: JSON.stringify({
        message: 'View count updated successfully',
        view_count: response.Attributes.ViewCount,
      }),
    };
  } catch (error) {
    console.log('Failed to update view count');
    console.log(error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        error: error.message,
        reference: context.awsRequestId,
      }),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': corsOrigin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
    };
  }
};
