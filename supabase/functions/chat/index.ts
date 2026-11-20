import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {createClient} from "jsr:@supabase/supabase-js@2";
import OpenAI from "npm:openai@7.2.0";
import {corsHeaders} from "../_shared/cors.ts";

const supabase = createClient(
    Deno.env.get("FUNCTION_REST_URL"),
    Deno.env.get("VITE_SUPABASE_ANON_KEY")
);

const openai = new OpenAI({
    apiKey: Deno.env.get("OPENAI_API_KEY"),
    baseURL: Deno.env.get("OPENAI_ENDPOINT"),
});

const getSystemPrompt = async (treeId: string) => {
    const {data, error} = await supabase
        .from("trees")
        .select("*")
        .eq("uuid", treeId)
        .single();

    if (error) {
        console.error("Error fetching system prompt:", error);
        return Deno.env.get("OPENAI_SYSTEM_PROMPT")!;
    }

    return (
        Deno.env.get("OPENAI_SYSTEM_PROMPT")! +
        "\n\n" +
        "Here are some information about you: " +
        "Botanischer Name: " +
        data.tree_type_botanic +
        ", " +
        "Deutscher Name: " +
        data.tree_type_german +
        ", Stammdurchmesser: " +
        data.trunk_diameter +
        "cm, Höhe: " +
        data.height +
        "m, Kronendurchmesser: " +
        data.crown_diameter +
        "m."
    );
};

Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", {
            headers: {...corsHeaders},
        });
    }



    const requestData = await req.json();
    const treeId: string = requestData.treeId;
    const messages: Array<{ role: string; content: string }> =
        requestData.messages || [];

    const treeData = await supabase.from("trees").select("*").eq("uuid", treeId);
    if (treeData.error) {
        console.error("[BB] Error fetching tree data:", treeData.error);
    } else {
        console.log("[BB] Found Tree data!");
    }


    const response = await openai.chat.completions.create({
        model: Deno.env.get("OPENAI_MODEL"),
        temperature: Deno.env.get("OPENAI_TEMPERATURE"),
        messages: [
            {
                role: "system",
                content: await getSystemPrompt(treeId),
            },
            {
                role: "user",
                content: Deno.env.get("OPENAI_FIRST_USER_PROMPT")!,
            },
            ...messages.map((message) => ({
                role: message.role,
                content: message.content,
            })),
        ]
    });

    return new Response(
        JSON.stringify({
            messages: [
                {
                    role: response.choices[0].message.role,
                    content: response.choices[0].message.content,
                },
            ],
        }),
        {
            headers: {...corsHeaders},
        }
    );
});
