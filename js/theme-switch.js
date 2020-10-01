import {LitElement, html, css} from 'lit-element';
import '@material/mwc-switch';

import {styles} from './css.js';

customElements.define('theme-switch', class extends LitElement {
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host {
			display: flex;
			flex-direction: column;
			align-items: center;
			margin-left: 1em;
			margin-right: 1em;
		}
		label {
			margin-bottom: 0.2em;
		}
		mwc-switch { --mdc-theme-secondary: #0f0 }
		`];
	}
	render() {
		return html`
		<label for="theme-switch"><small>Dark mode</small></label>
		<mwc-switch id="theme-switch" @change="${this.toggleTheme}"
				?checked="${document.documentElement.getAttribute('data-theme') == 'dark'}">
		</mwc-switch>
		`;
	}
	toggleTheme(e) {
		if (e.target.checked) {
			document.documentElement.setAttribute('data-theme', 'dark');
			localStorage.setItem('theme', 'dark');
		} else {
			document.documentElement.setAttribute('data-theme', 'light');
			localStorage.setItem('theme', 'light');
		}
	}
});
