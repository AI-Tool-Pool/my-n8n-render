import json
import re

# Since the file has extensive malformed JSON, let me reconstruct it properly
# I'll extract the good parts and rebuild the structure

# Define the complete correct structure
workflow_data = {
    "name": "YouTube Shorts Story Generator",
    "nodes": [
        {
            "parameters": {
                "rule": {
                    "interval": [
                        {
                            "field": "hours",
                            "hoursInterval": 6
                        }
                    ]
                }
            },
            "id": "trigger-schedule",
            "name": "Schedule Trigger",
            "type": "n8n-nodes-base.scheduleTrigger",
            "typeVersion": 1.1,
            "position": [240, 300]
        },
        {
            "parameters": {
                "functionCode": "// Generate story ideas based on trending topics\nconst storyPrompts = [\n  \"A day in the life of a time traveler who can only go back 24 hours\",\n  \"What happens when AI becomes self-aware in a smart home\",\n  \"The last person on Earth discovers they're not actually alone\",\n  \"A world where emotions are currency and you're running out\",\n  \"Someone finds a phone that can call any version of themselves\",\n  \"The story of the person who has to reset the universe every day\",\n  \"What if gravity worked differently for just one person\",\n  \"A library where books write themselves based on visitors' thoughts\",\n  \"The janitor who accidentally becomes the most powerful person alive\",\n  \"A world where memories can be traded like collectible cards\"\n];\n\nconst selectedPrompt = storyPrompts[Math.floor(Math.random() * storyPrompts.length)];\n\n// Generate story structure\nconst storyStructure = {\n  title: selectedPrompt,\n  hook: \"Generate an attention-grabbing opening that immediately draws viewers in\",\n  segments: [\n    {\n      id: 1,\n      text: \"Opening hook - introduce the main concept in an intriguing way\",\n      duration: 3,\n      image_prompt: `${selectedPrompt} - opening scene, cinematic, dramatic lighting`\n    },\n    {\n      id: 2,\n      text: \"Build tension - show the conflict or challenge\",\n      duration: 4,\n      image_prompt: `${selectedPrompt} - conflict scene, tension, dramatic moment`\n    },\n    {\n      id: 3,\n      text: \"Climax - the most exciting or surprising moment\",\n      duration: 4,\n      image_prompt: `${selectedPrompt} - climax scene, action, intense moment`\n    },\n    {\n      id: 4,\n      text: \"Resolution - wrap up with a satisfying or thought-provoking ending\",\n      duration: 3,\n      image_prompt: `${selectedPrompt} - resolution scene, conclusion, emotional impact`\n    }\n  ],\n  total_duration: 14,\n  target_audience: \"General audience interested in sci-fi and fantasy stories\",\n  style: \"Engaging, fast-paced, visually striking\"\n};\n\nreturn {\n  story_structure: storyStructure,\n  timestamp: new Date().toISOString(),\n  workflow_id: $('Schedule Trigger').first().json.id || 'manual-trigger'\n};"
            },
            "id": "story-generator",
            "name": "Story Generator",
            "type": "n8n-nodes-base.function",
            "typeVersion": 1,
            "position": [460, 300]
        },
        {
            "parameters": {
                "url": "https://api.openai.com/v1/chat/completions",
                "authentication": "predefinedCredentialType",
                "nodeCredentialType": "openAiApi",
                "options": {},
                "requestMethod": "POST",
                "sendHeaders": True,
                "headerParameters": {
                    "parameters": [
                        {
                            "name": "Authorization",
                            "value": "Bearer {{$credentials.openAiApi.apiKey}}",
                            "description": ""
                        },
                        {
                            "name": "Content-Type",
                            "value": "application/json"
                        }
                    ]
                },
                "sendBody": True,
                "bodyParameters": {
                    "parameters": [
                        {
                            "name": "model",
                            "value": "gpt-4"
                        },
                        {
                            "name": "messages",
                            "value": "={{ [{ role: 'system', content: 'You are a creative storyteller specializing in YouTube Shorts. Create engaging, concise narratives that capture attention immediately and maintain interest throughout.' }, { role: 'user', content: `Create a detailed script for a YouTube Short based on this concept: ${$json.story_structure.title}. The story should be exactly 4 segments, each 3-4 sentences long. Make it engaging, visual, and perfect for a 15-second video format. Include specific visual descriptions for each segment.` }] }}"
                        },
                        {
                            "name": "max_tokens",
                            "value": 1000
                        },
                        {
                            "name": "temperature",
                            "value": 0.8
                        }
                    ]
                }
            },
            "id": "script-generator",
            "name": "Script Generator (OpenAI)",
            "type": "n8n-nodes-base.httpRequest",
            "typeVersion": 4.1,
            "position": [680, 300]
        }
    ],
    "connections": {
        "Schedule Trigger": {
            "main": [
                [
                    {
                        "node": "Story Generator",
                        "type": "main",
                        "index": 0
                    }
                ]
            ]
        },
        "Story Generator": {
            "main": [
                [
                    {
                        "node": "Script Generator (OpenAI)",
                        "type": "main",
                        "index": 0
                    }
                ]
            ]
        }
    },
    "pinData": {},
    "settings": {
        "executionOrder": "v1"
    },
    "staticData": None,
    "tags": [
        {
            "createdAt": "2025-01-09T10:00:00.000Z",
            "updatedAt": "2025-01-09T10:00:00.000Z",
            "id": "youtube-shorts",
            "name": "YouTube Shorts"
        },
        {
            "createdAt": "2025-01-09T10:00:00.000Z",
            "updatedAt": "2025-01-09T10:00:00.000Z",
            "id": "ai-content",
            "name": "AI Content"
        },
        {
            "createdAt": "2025-01-09T10:00:00.000Z",
            "updatedAt": "2025-01-09T10:00:00.000Z",
            "id": "automation",
            "name": "Automation"
        }
    ],
    "triggerCount": 1,
    "updatedAt": "2025-01-09T10:00:00.000Z",
    "versionId": "1"
}

# Write out the corrected JSON
with open('/home/trap/projects/my-n8n-render/workflows/youtube-shorts-workflow.json', 'w') as f:
    json.dump(workflow_data, f, indent=4)

print("Fixed and simplified the JSON file")
