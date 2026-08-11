/**
 * Shorty's schedule-reading backend.
 *
 * The one job of this Worker: take a photo of a class schedule from the app, send it to
 * Claude's vision API, and hand back structured weekly schedule entries. It exists only
 * because a real Anthropic API key can never live inside the iOS app itself -- anyone
 * could pull it out of the app binary and run up charges on it. Holding the key here,
 * server-side, is the only safe place for it.
 *
 * This intentionally does nothing else: no database, no user accounts, no storage.
 * Nothing it receives is retained after the response is sent.
 */

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001";
const ANTHROPIC_VERSION = "2023-06-01";

export default {
  async fetch(request, env) {
    if (request.method !== "POST") {
      return jsonResponse({ error: "POST only" }, 405);
    }

    // A shared secret embedded in the app isn't a real secret (anyone can extract it
    // from the binary), but it stops the endpoint from being wide open to anyone who
    // finds the URL, and it's the cheap, honest half of the defense here -- the
    // expensive half is that every call costs real money against the Anthropic account,
    // which is exactly why this whole feature is gated behind Shorty Plus in the app.
    const providedSecret = request.headers.get("X-Shorty-Secret");
    if (!env.SHARED_SECRET || providedSecret !== env.SHARED_SECRET) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return jsonResponse({ error: "Invalid JSON body" }, 400);
    }

    const imageBase64 = body.image;
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      return jsonResponse({ error: "Missing 'image' field (base64-encoded JPEG)" }, 400);
    }

    const anthropicRequest = {
      model: ANTHROPIC_MODEL,
      max_tokens: 2048,
      tools: [
        {
          name: "record_schedule",
          description: "Records every recurring class/schedule entry detected in the photo.",
          input_schema: {
            type: "object",
            properties: {
              entries: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    title: {
                      type: "string",
                      description: "The course/class name, e.g. 'Organic Chemistry'. If genuinely unreadable, use 'Class'.",
                    },
                    weekdays: {
                      type: "array",
                      items: { type: "integer", minimum: 1, maximum: 7 },
                      description: "Days this class meets, using 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday.",
                    },
                    startHour: { type: "integer", minimum: 0, maximum: 23, description: "24-hour clock." },
                    startMinute: { type: "integer", minimum: 0, maximum: 59 },
                    endHour: { type: "integer", minimum: 0, maximum: 23, description: "24-hour clock." },
                    endMinute: { type: "integer", minimum: 0, maximum: 59 },
                  },
                  required: ["title", "weekdays", "startHour", "startMinute", "endHour", "endMinute"],
                },
              },
            },
            required: ["entries"],
          },
        },
      ],
      tool_choice: { type: "tool", name: "record_schedule" },
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
            {
              type: "text",
              text:
                "This is a photo of a student's class schedule, likely a grid or table (course, days, time, room in columns). " +
                "Extract every recurring weekly class as one entry each -- do not create a separate entry per meeting day; " +
                "instead list all of that class's days together in its 'weekdays' array. Always use 24-hour times in your " +
                "answer. If the photo doesn't show AM/PM for a class, infer it from context: college classes essentially " +
                "never meet 1-7 AM, so an unmarked time in that range almost always means the afternoon/evening. Skip " +
                "anything that isn't a recurring weekly class (e.g. one-off exam dates, a semester calendar, unrelated text).",
            },
          ],
        },
      ],
    };

    let anthropicResponse;
    try {
      anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body: JSON.stringify(anthropicRequest),
      });
    } catch (error) {
      return jsonResponse({ error: `Couldn't reach Claude API: ${error.message}` }, 502);
    }

    if (!anthropicResponse.ok) {
      const detail = await anthropicResponse.text();
      return jsonResponse({ error: `Claude API error (${anthropicResponse.status}): ${detail}` }, 502);
    }

    const result = await anthropicResponse.json();
    const toolUse = (result.content || []).find((block) => block.type === "tool_use" && block.name === "record_schedule");
    if (!toolUse || !Array.isArray(toolUse.input?.entries)) {
      return jsonResponse({ error: "Claude didn't return structured schedule data" }, 502);
    }

    return jsonResponse({ entries: toolUse.input.entries }, 200);
  },
};

function jsonResponse(body, status) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
