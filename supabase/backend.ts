import dotenv from 'dotenv';
dotenv.config()

const options = {
    method: 'POST',
    headers: {
        accept: 'application/json',
        'content-type': 'application/json',
        versionID: "production",
        Authorization: process.env.VF_API_KEy
    },
    body: JSON.stringify({
        action: {type: 'launch'},
        config: {
            tts: false,
            stripSSML: true,
            stopAll: true,
            excludeTypes: ['block', 'debug', 'flow']
        }
    })
};

let baumhoehe = 15;
let baumart = "Winterlinde";
let kronendurchmesser = 5;
let baum_oid = 1234;

let user_id;

type Message = {
    text: string;
    type: string;
    sender: string;
    clickable?: boolean;
    source?: string;
};

let messages: (Message & { clickable?: boolean })[] = [];
let newMessage = '';
let chatAvailable = false;

const startConversation = async () => {
    user_id = crypto.randomUUID();

    await fetch('https://general-runtime.voiceflow.com/state/user/' + user_id + '/variables?logs=off', {
        ...options, method: "PATCH", body: JSON.stringify({
            baumhoehe, baumart, kronendurchmesser, baum_oid
        })
    })
        .then(response => response.json())
        .then(response => console.log("after setting variables", response))
        .catch(err => console.log("after setting variables error", err))
    await fetch('https://general-runtime.voiceflow.com/state/user/' + user_id + '/interact?logs=off', options)
        .then(response => response.json())
        .then(response => {
            console.log("Start interaction", response)
            response.filter(m => m.type === "text").forEach(msg => {
                messages = [...messages, {text: msg.payload.message, type: "text", sender: 'bot'}];
            })
            chatAvailable = true;
            console.log(messages);
        })
        .catch(err => console.error("after start interaction error", err));
}

const sendMessage = async (userShownMessage, sentMessage) => {
    messages = [...messages, {text: userShownMessage, type: "text", sender: 'user'}].map(m => {
        if ('clickable' in m) {
            m.clickable = false;
        }
        return m;
    });
    await fetch('https://general-runtime.voiceflow.com/state/user/' + user_id + '/interact?logs=off', {
        ...options, body: JSON.stringify({
            action: {type: 'text', payload: sentMessage}
        })
    })
        .then(response => response.json())
        .then(response => {
            console.log("Send Message response", response)
            let totalDelay = 0;
            response.forEach(msg => {
                if (msg.payload && msg.payload.delay) {
                    totalDelay += msg.payload.delay;
                    console.log("total delay", totalDelay, msg);
                }
                setTimeout(() => {
                    switch (msg.type) {
                        case "text":
                            messages = [...messages, {text: msg.payload.message, type: "text", sender: 'bot'}];
                            break;
                        case "choice":
                            messages = [...messages, {
                                text: "Wähle eine Option aus:",
                                type: "small",
                                sender: 'bot'
                            }, ...msg.payload.buttons.map(b => {
                                return {
                                    label: b.request.payload.intent.name,
                                    text: b.name,
                                    type: "choice",
                                    sender: 'bot',
                                    clickable: true
                                }
                            })];
                            console.log("all choices appended", messages);
                            break;
                        case "visual":
                            messages = [...messages, {
                                text: "Grafik",
                                type: "visual",
                                sender: "bot",
                                source: msg.payload.image
                            }]
                            break;
                        case "end":
                            chatAvailable = false;
                            break;
                    }
                }, totalDelay);
            })
            newMessage = ''; // Clear the input field
            console.log(messages)
        })
        .catch(err => console.error("after start interaction error", err));
}