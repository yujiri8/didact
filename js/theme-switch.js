import {LitElement, html, css} from 'lit-element';

import {styles} from './css.js';

customElements.define('theme-switch', class extends LitElement {
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host {
			display: flex;
			flex-direction: column;
			align-items: center;
		}
		label {
			margin-bottom: 0.2em;
		}
		`];
	}
	render() {
		return html`
		<label for="theme-switch"><small>Light mode</small></label>
		<input type="checkbox" id="theme-switch" @change="${this.toggleTheme}"
				?checked="${document.documentElement.getAttribute('data-theme') == 'light'}">
		`;
	}
	toggleTheme(e) {
		if (e.target.checked) {
			document.documentElement.setAttribute('data-theme', 'light');
			localStorage.setItem('theme', 'light');
		} else {
			document.documentElement.setAttribute('data-theme', 'dark');
			localStorage.setItem('theme', 'dark');
		}
	}
});
