import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const supabase = createClient(
  Deno.env.get("FUNCTION_REST_URL"),
  Deno.env.get("VITE_SUPABASE_ANON_KEY")
);

// Initial request could be:
// POST /functions/v1/chat
// {
//   treeId: "123"
// }

// Response could be:
// {
//   sessionId: "456",
//   response: {
//     text: "Hello, how can I help you today?"
//   }
// }

// Subsequent requests could be:
// POST /functions/v1/chat
// {
//   sessionId: "456",
//   text: "I want to know more about the product"
// }

// Response could be:
// {
//   sessionId: "456",
//   response: {
//     text: "The product is a great product"
//   }

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: { ...corsHeaders },
    });
  }

  // Get the request body
  // - specifically tree id, session id, and text
  const { treeId, sessionId, text } = await req.json();

  // If session id is not present
  if (!sessionId) {
    // - generate session id
    const newSessionId = crypto.randomUUID();
    console.log("[BB] New session id:", newSessionId);

    // - get tree information
    const treeData = await supabase
      .from("trees")
      .select("*")
      .eq("uuid", treeId);
    if (treeData.error) {
      console.error("[BB] Error fetching tree data:", treeData.error);
    } else {
      console.log("[BB] Found Tree data!");
    }

    // - send request to configure variables in VoiceFlow
    const variableResponse = await fetch(
      `https://general-runtime.voiceflow.com/state/user/${newSessionId}/variables?logs=off`,
      {
        method: "PATCH",
        headers: {
          "content-type": "application/json",
          authorization: Deno.env.get("VOICEFLOW_API_KEY"),
        },
        // TODO: Variablennamen in VoiceFlow anpassen auf neues Datenformat aus Supabase.
        body: JSON.stringify({
          baum_oid: treeId,
          baumart: treeData.data[0].tree_type_german,
          baumhoehe: treeData.data[0].height,
          kronendurchmesser: treeData.data[0].crown_diameter,
        }),
      }
    );
    if (variableResponse.error) {
      console.error("[VF] Error configuring variables:");
    } else {
      console.log("[VF] Variables configured successfully!");
    }

    // - start conversation by sending launch action
    const startConversationResponse = await fetch(
      `https://general-runtime.voiceflow.com/state/user/${newSessionId}/interact?logs=off`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: Deno.env.get("VOICEFLOW_API_KEY"),
        },
        body: JSON.stringify({
          action: {
            type: "launch",
          },
          config: {
            tts: false,
            stripSSML: true,
            stopAll: true,
            excludeTypes: ["block", "debug", "flow"],
          },
        }),
      }
    );

    let returnedMessages = await startConversationResponse.json();
    if (startConversationResponse.status !== 200) {
      console.error("[VF] Error starting conversation");
    } else {
      console.log("[VF] Conversation started successfully!");
    }

    // - send response back to the user with session id
    return new Response(
      JSON.stringify({
        sessionId: newSessionId,
        messages: returnedMessages,
      }),
      {
        headers: {
          ...corsHeaders,
          "content-type": "application/json",
        },
        status: 200,
      }
    );
  } else {
    // If session id is present

    // - send request to VoiceFlow with session id and text
    const updateConversationResponse = await fetch(
      `https://general-runtime.voiceflow.com/state/user/${sessionId}/interact?logs=off`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: Deno.env.get("VOICEFLOW_API_KEY"),
        },
        body: JSON.stringify({
          action: {
            type: "text",
            payload: text,
          },
        }),
      }
    );

    // - send response back to the user with session id
    return new Response(
      JSON.stringify({
        sessionId,
        messages: await updateConversationResponse.json(),
      }),
      {
        headers: {
          ...corsHeaders,
          "content-type": "application/json",
        },
      }
    );
  }
});
