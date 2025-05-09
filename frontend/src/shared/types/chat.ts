// src/lib/types.ts

export interface ChatButton {
	label: string;
	request: {
		type: string;
		payload?: any;
	};
}

export interface Message {
	text: string;
	label: string;
	type: 'text' | 'choice';
	sender: 'bot' | 'user';
	ai?: boolean;
	buttons?: ChatButton[];
}

export interface RawMessage {
	time: number;
	type: string;
	payload: any;
}

// /**
//  * RawMessage entspricht exakt dem Nachrichtenformat,
//  * das von der Voiceflow Runtime API zurückgegeben wird.
//  * 
//  * Dieses Format enthält alle Typen (text, choice, no-reply, etc.)
//  * sowie optionale Zusatzinfos wie ai, delay, slate usw.
//  */
// export interface RawMessage {
// 	/**
// 	 * Der Typ der Nachricht (z. B. "text", "choice", "visual", "no-reply")
// 	 */
// 	type: string;
  
// 	/**
// 	 * Zeitstempel der Nachricht (in ms seit Unix-Epoch)
// 	 */
// 	time: number;
  
// 	/**
// 	 * Nutzdaten der Nachricht – Struktur hängt vom Typ ab
// 	 */
// 	payload: {
// 	  /**
// 	   * Der eigentliche Nachrichtentext (bei Typ "text")
// 	   */
// 	  message?: string;
  
// 	  /**
// 	   * Ob die Nachricht als KI-generiert markiert ist
// 	   */
// 	  ai?: boolean;
  
// 	  /**
// 	   * Optional: Zeitverzögerung vor Anzeige der Nachricht
// 	   */
// 	  delay?: number;
  
// 	  /**
// 	   * Strukturierte Textrepräsentation (Slate.js-kompatibel),
// 	   * meist nur bei Typ "text" enthalten
// 	   */
// 	  slate?: unknown;
  
// 	  /**
// 	   * Nur bei "choice": eine Liste auswählbarer Buttons
// 	   */
// 	  buttons?: {
// 		name: string;
// 		request: {
// 		  type: string;
// 		  payload?: {
// 			label?: string;
// 			intent?: {
// 			  name: string;
// 			};
// 		  };
// 		};
// 	  }[];
  
// 	  /**
// 	   * Nur bei "visual": URL eines Bildes (z. B. zur Anzeige im Chat)
// 	   */
// 	  image?: string;
  
// 	  /**
// 	   * Nur bei "no-reply": Zeit bis Timeout
// 	   */
// 	  timeout?: number;
  
// 	  /**
// 	   * Nur bei "path": enthält den nächsten internen Pfadnamen
// 	   */
// 	  path?: string;
// 	};
//   }
  