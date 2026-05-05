import json
import urllib3
import boto3

BOT_TOKEN = ""

def sendReply(chat_id, message):
    reply = {
        "chat_id": chat_id,
        "text": message
    }

    http = urllib3.PoolManager()
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendMessage"
    encoded_data = json.dumps(reply).encode('utf-8')
    http.request('POST', url, body=encoded_data, headers={'Content-Type': 'application/json'})

    print(f"*** Reply : {encoded_data}")

def ask_bedrock(prompt):
    bedrock = boto3.client('bedrock-runtime', region_name='eu-north-1')
    
    # model_id = 'anthropic.claude-3-haiku-20240307-v1:0'
    # body = json.dumps({
    #     "anthropic_version": "bedrock-2023-05-31",
    #     "max_tokens": 1000,
    #     "messages": [
    #         {
    #             "role": "user",
    #             "content": [{"type": "text", "text": prompt}]
    #         }
    #     ]
    # })

    model_id='eu.amazon.nova-micro-v1:0'
    body=json.dumps({
        'messages': [{
            'role': 'user',
            'content': [{'text': prompt}]
        }],
        'inferenceConfig': {
            'maxTokens': 1024
        }
    })
    
    try:
        response = bedrock.invoke_model(
            body=body,
            modelId=model_id,
            accept='application/json',
            contentType='application/json'
        )
        response_body = json.loads(response.get('body').read())
        # return response_body.get('content')[0].get('text')
        return response_body['output']['message']['content'][0]['text']
    except Exception as e:
        print(f"Error calling Bedrock: {e}")
        return "I'm sorry, I'm finding it hard to think right now. (Server Error)"


def lambda_handler(event, context):
    body = json.loads(event['body'])

    print("*** Received event")

    chat_id = body['message']['chat']['id']
    user_name = body['message']['from']['username']
    message_text = body['message']['text'] if 'text' in body['message'] else '<not available>'

    print(f"*** chat id: {chat_id}")
    print(f"*** user name: {user_name}")
    print(f"*** message text: {message_text}")
    print(json.dumps(body))

    # Ask bedrock instead of sending a default string reply
    if message_text != '<not available>':
        reply_message = ask_bedrock(message_text)
    else:
        reply_message = "I am a text bot. Please send me a text message."

    sendReply(chat_id, reply_message)

    return {
        'statusCode': 200,
        'body': json.dumps('Message processed successfully')
    }