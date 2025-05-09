<script lang="ts">

  let messages: Array<{ text: string, label: string, type: string, sender: string, source?: string, clickable?: boolean }> = [];
  let newMessage: string = '';
  let chatAvailable: boolean = true;

  messages = [
    {
      text: "Hallo! Ich bin eine Winter Linde. Wie sehe ich aus?",
      label: "Willkommen",
      type: "text",
      sender: "bot"
    },
    {
      text: "prächtig",
      label: "gut",
      type: "choice",
      sender: "bot",
      clickable: true
    },
    {
      text: "durstig",
      label: "durst",
      type: "choice",
      sender: "bot",
      clickable: true
    },
    {
      text: "unklar",
      label: "unklar",
      type: "choice",
      sender: "bot",
      clickable: true
    },
    {
      text: "Du bist sehr schön",
      label: "Antwort",
      type: "text",
      sender: "user",
      clickable: true
    },
  ];

  function removeChatbox() {
    // Implementation for removing chatbox
    let overlay = document.getElementById("chat-overlay");
    if (overlay) {
      let parent = overlay.parentElement;
      if (parent) {
        parent.removeChild(overlay);
      }
    }
  }

  function sendMessage(text: string, label: string) {
    // Implementation for sending message
  }

  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && newMessage !== '') {
      sendMessage(newMessage, newMessage);
    }
  }
</script>

<div id="chat-overlay" class=" top-0 left-0 w-full h-full bg-black bg-opacity-50 z-50">
  <div id="chat-container" class="bg-gray-200 flex flex-col h-full w-full fixed top-0 border border-gray-800 rounded m-2">
    <div class="close-chat flex justify-end m-2 text-gray-800">
      <svg id="close-button" on:click={removeChatbox} on:keypress={removeChatbox}
           fill="000" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"
           class="w-6 h-6 cursor-pointer">
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
      </svg>
    </div>
    <div class="chat-messages-wrapper flex-grow overflow-y-auto flex flex-col justify-end mx-2">
      {#each messages as { text, label, type, sender, source, clickable }}
        <div class="message-wrapper {sender === 'user' ? 'justify-end' : ''} flex">
          {#if type === "choice"}
            <button class="message {sender === 'user' ? 'bg-gray-300 text-gray-800' : 'bg-green-900 text-white'} mb-2 p-2 rounded max-w-3/4 text-left"
                    on:click={(e) => {clickable && sendMessage(text, label)}}>
              {#if sender === "bot" && text === "Gesundheits-Check"}
                🌡️
              {:else if sender === "bot" && text === "Wasserbedarf"}
                💧
              {:else if sender === "bot" && text === "Bauminfos"}
                🌳
              {/if}
              {text}
            </button>
          {:else if type === "text"}
            <div class="message {sender === 'user' ? 'bg-gray-300 text-gray-800' : 'bg-green-900 text-white'} mb-2 p-2 rounded max-w-3/4 text-left">
              {text}
            </div>
          {:else if type === "small"}
            <div class="message {sender === 'user' ? 'bg-gray-300 text-gray-800' : 'bg-green-900 text-white'} mb-2 p-2 rounded max-w-3/4 text-left text-sm">
              {text}
            </div>
          {:else if type === "visual"}
            <div class="message-img {sender === 'user' ? 'bg-gray-300 text-gray-800' : 'bg-green-900 text-white'} mb-2 p-2 rounded max-w-3/4 text-left">
              <img class="message-img" src="{source}" alt="grafik Regenmenge"/>
            </div>
          {/if}
        </div>
      {/each}
    </div>

    <div class="new-chat-messages flex m-2">
      <div class="new-chat-messages-wrapper flex w-full">
        <input
          disabled={!chatAvailable}
          bind:value={newMessage}
          placeholder={chatAvailable ? "Schreibe deine Nachricht..." : "Chat beendet."}
          on:keydown={handleKeydown}
          class="flex-grow p-2 border border-gray-300 rounded"
        />
        <button
          disabled={!chatAvailable}
          on:click={(e) => {
            if (newMessage !== '') {
              sendMessage(newMessage, newMessage);
            }
          }}
          class="ml-2 p-2 cursor-pointer"
        >
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-6 h-6">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
</div>

<style>


    .message-wrapper {
        display: flex;
        flex-direction: row;
    }

    .message-wrapper-user {
        justify-content: flex-end;
    }

    .message {
        margin-bottom: 10px;
        padding: 8px;
        border-radius: 5px;
        max-width: 70%;
        text-align: left;
    }

    .user-message {
        background-color: #ddd;
        align-self: flex-end;
        color: #333;

    }

    .bot-message {
        background-color: #053B06;
        color: #fff;
        align-self: flex-start;
    }

    .close-chat {
        display: flex;
        flex-direction: row;
        justify-content: end;
        margin: 10px;
        color: #333;
        box-sizing: border-box;
    }

    .close-chat #close-button {
        width: 20px;
        height: 20px;
        cursor: pointer;
    }

    .chat-messages-wrapper {
        flex-grow: 1;
        overflow-y: auto;
        flex-direction: column;
        justify-content: flex-end;
        margin: 0 10px;
    }

    .new-chat-messages {
        display: flex;
        margin: 10px;
        box-sizing: border-box;
        flex-direction: row;
        flex-shrink: 1;
    }

    .new-chat-messages input {
        background: #ddd;
        border: none;
        color: #000;
    }

    .new-chat-messages input::placeholder {
        color: #333;
    }

    .new-chat-messages button {
        background-color: transparent;
        color: #000;
        border: none;
    }

    .new-chat-messages button svg {
        width: 24px;
        height: 24px;
        color: #000;
    }

    .new-chat-messages-wrapper {
        display: flex;
        width: 100%
    }

    .new-chat-messages-wrapper input {
        display: flex;
        flex-grow: 1;
        padding: 8px;
        box-sizing: border-box;
        border: 1px solid #ccc;
        border-radius: 5px;
    }

    .new-chat-messages-wrapper button {
        margin-left: -40px;
        padding: 8px;
        cursor: pointer;
    }


    .message-small {
        background-color: transparent;
        padding-bottom: 0;
        margin-bottom: 10px;
        color: #333;
        font-size: 0.8em;
    }

    .message-img {
        align-self: flex-start;
        max-width: 90%;
        margin-bottom: 10px;
        padding: 8px;
        border-radius: 5px;
    }


</style>