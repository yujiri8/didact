import {LitElement, html, css} from 'lit-element';
import '@material/mwc-dialog';

import * as util from './util.js';
import {styles} from './css.js';

var canceled = Symbol('canceled');

customElements.define('auth-popup', class extends LitElement {
	static get properties() {
		return {
			open: {type: Boolean, attribute: false},
			email: {type: String, attribute: false},
			errMsg: {type: String, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host {	display: block; }
		input { /* The popup looks better as black-on-white even in dark mode. */
			color: initial;
			background-color: initial;
		}
		`];
	}
	render() {
		return html`
		<mwc-dialog ?open="${this.open}" @closed="${this.handleClose}">
			<p class="bad">${this.errMsg}</p>
			<label for="email">Email:</label>
			<input type="text" id="email">
			<br>
			<label for="pw">Password:</label>
			<input type="password" id="pw">
			<br>
			<button slot="primaryAction" dialogAction="submit">Submit</button>
			<button slot="secondaryAction" dialogAction="cancel">Cancel</button>
		</mwc-dialog>
		`;
	}
	async run(initialMsg) {
		// Reset stuff incase there was a canceled attempt before.
		this.email = util.readCookie('email');
		this.shadowRoot.getElementById('email').value = this.email;
		this.shadowRoot.getElementById('pw').value = '';
		this.errMsg = initialMsg || '';
		// Retry until they succeed or cancel (which throws an exception).
		while (true) {
			this.open = true;
			// A hack that escapes the promise callback from the promise, so we can await properly.
			const creds = await new Promise(resolve => {this.resolve = resolve});
			if (creds.cancel) throw canceled;
			const resp = await util.api('POST', 'users/login', undefined, creds);
			if (resp.ok) return;
			this.errMsg = 'Invalid credentials.';
		}
	}
	handleClose(e) {
		const email = this.shadowRoot.getElementById('email').value;
		// Set the email cookie if they didn't cancel.
		if (e.detail.action == 'submit') util.setCookie('email', email);
		this.open = false;
		this.resolve({
			cancel: e.detail.action != 'submit',
			email: email,
			pw: this.shadowRoot.getElementById('pw').value,
		});
	}
});
