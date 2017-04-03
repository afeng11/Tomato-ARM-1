<!--
Tomato GUI
Copyright (C) 2006-2007 Jonathan Zarate
http://www.polarcloud.com/tomato/

Virtual Wireless Interfaces web interface & extensions
Copyright (C) 2012 Augusto Bott
http://code.google.com/p/tomato-sdhc-vlan/
Some portions Copyright (C) Jean-Yves Avenard
mailto:jean-yves@avenard.org

For use with Tomato Firmware only.
No part of this file may be used without permission.
LAN Access admin module by Augusto Bott
--><title><% translate("Virtual Wireless Interfaces"); %></title>
<content>
	<style type="text/css">
		#wlif-grid .co2,
		#wlif-grid .co3,
		#wlif-grid .co4 {
			text-align: center;
		}
		#wlif-grid .centered {
			text-align: center;
		}
		#spin {
			visibility: hidden;
			vertical-align: middle;
		}
	</style>
	<script type="text/javascript" src="js/md5.js"></script>
	<script type="text/javascript" src="js/wireless.jsx?_http_id=<% nv(http_id); %>"></script>
	<script type="text/javascript" src="js/interfaces.js"></script>
	<script type="text/javascript" src="js/wireless.js"></script>
	<script type="text/javascript">
		// <% nvram("nas_alternate,wl_auth,wl_auth_mode,wl_bss_enabled,wl_channel,wl_closed,wl_corerev,wl_crypto,wl_hwaddr,wl_ifname,wl_key,wl_key1,wl_key2,wl_key3,wl_key4,wl_lazywds,wl_mode,wl_nband,wl_nbw_cap,wl_nctrlsb,wl_net_mode,wl_passphrase,wl_phytype,wl_radio,wl_radius_ipaddr,wl_radius_key,wl_radius_port,wl_security_mode,wl_ssid,wl_vifs,wl_wds,wl_wds_enable,wl_wep_bit,wl_wpa_gtk_rekey,wl_wpa_psk,wl_bss_maxassoc,wl_wme,lan_ifname,lan_ifnames,lan1_ifname,lan1_ifnames,lan2_ifname,lan2_ifnames,lan3_ifname,lan3_ifnames,t_features");%>

		var vifs_possible = [];
		var vifs_defined = [];
		var vifs_deleted = [];
		var max_no_vifs = 0;

		var wl_modes_available = [];

		wmo = {'ap':'<% translate("Access Point"); %>','apwds':'<% translate("Access Point + WDS"); %>','sta':'<% translate("Wireless Client"); %>','wet':'<% translate("Wireless Ethernet Bridge"); %>','wds':'<% translate("WDS"); %>'};

		tabs = [['overview','<% translate("Overview"); %>']];

		var xob = null;
		var refresher = [];
		var nphy = features('11n');

		var ghz = [];
		var bands = [];
		var nm_loaded = [], ch_loaded = [], max_channel = [];

		for (var uidx = 0; uidx < wl_ifaces.length; ++uidx) {
			if (wl_sunit(uidx) < 0) {
				var b;
				b = [];
				for (var i = 0; i < wl_bands[uidx].length; ++i) {
					b.push([wl_bands[uidx][i] + '', (wl_bands[uidx][i] == '1') ? '5 GHz' : '2.4 GHz']);
				}
				bands.push(b);

				b = [];
				ghz.push(b);

				nm_loaded.push(0);
				ch_loaded.push(0);
				max_channel.push(0);
				refresher.push(null);
			}
		}

		function spin(x, unit) {
			for (var u = 0; u < wl_ifaces.length; ++u) {
				E('_f_wl'+wl_unit(u)+'_scan').disabled = x;
			}
			var e = E('_f_wl'+unit+'_scan');
			if (x) e.value = 'Scan ' + (wscan.tries + 1);
			else e.value = 'Scan';
			E('spin'+unit).style.visibility = x ? 'visible' : 'hidden';
		}

		earlyInit();

		wlg = new TomatoGrid();

		wlg.setup = function() {
			this.init('wlif-grid', '', max_no_vifs, [
				{ type: 'select', options: vifs_possible },
				{ type: 'checkbox', prefix: '<div class="centered">', suffix: '</div>' },
				{ type: 'text', maxlen: 32, size: 34, prefix: '<div class="centered">', suffix: '</div>' },
				{ type: 'select', options: wl_modes_available , prefix: '<div class="centered">', suffix: '</div>' },
				{ type: 'select', options: [[0,'<% translate("LAN"); %> (br0)'],[1,'<% translate("LAN2"); %> (br1)'],[2,'<% translate("LAN3"); %> (br2)'],[3,'<% translate("LAN4"); %> (br3)'],[4,'<% translate("none"); %>']] }
			]);

			this.headerSet(['<% translate("Interface"); %>', '<% translate("Enabled"); %>', 'SSID', '<% translate("Mode"); %>','<% translate("Bridge"); %>']);

			wlg.populate();

			wlg.canDelete = false;
			wlg.showNewEditor();
			wlg.resetNewEditor();
			if (wlg.getAllData().length >= max_no_vifs) {
				wlg.disableNewEditor(true);
			}
		}

		wlg.populate = function() {
			if (wlg.tb != null) {
				wlg.removeAllData();
				for (var uidx in vifs_defined) {
					if (typeof(vifs_defined[uidx][0]) == 'undefined') continue;
					var wmode = (((vifs_defined[uidx][7]) == 'ap') && ((nvram['wl' + u + '_wds_enable']) == '1')) ? 'apwds': (vifs_defined[uidx][7]);
					this.insertData(-1, [
						vifs_defined[uidx][0],
						vifs_defined[uidx][4],
						vifs_defined[uidx][8],
						wmode,
						vifs_defined[uidx][11].toString()
					]);
				}
			}
		}

		wlg.resetNewEditor = function() {
			var f = fields.getAll(this.newEditor);
			f[2].value = '';
			f[1].checked = 1;

			f[0].selectedIndex=0;
			var t = max_no_vifs;
			while((this.countVIF(f[0].options[f[0].selectedIndex].value) > 0) && (t > 0)) {
				f[0].selectedIndex = (f[0].selectedIndex%(max_no_vifs-1))+1;
				t--;
			}

			for(var i = 0; i < f[0].options.length ; i++) {
				f[0].options[i].disabled = (this.countVIF(f[0].options[i].value) > 0);
			}

			/* REMOVE-BEGIN */
			//	f[3].options[1].disabled = 1; // AP + WDS
			//	f[3].options[2].disabled = 1; // Wireless Client
			//	f[3].options[4].disabled = 1; // WDS
			/* REMOVE-END */
			f[3].selectedIndex = 0;
			for(var i = 0; i < f[3].options.length ; i++) {
				/* REMOVE-BEGIN */
				//		f[3].options[i].disabled = ((f[3].options[i].value != 'ap') && (f[3].options[i].value != 'wet'));
				/* REMOVE-END */
				f[3].options[i].disabled = (f[3].options[i].value != 'ap');
			}

			if (nvram.lan_ifname.length < 1)
				f[4].options[0].disabled=1;
			if (nvram.lan1_ifname.length < 1)
				f[4].options[1].disabled=1;
			if (nvram.lan2_ifname.length < 1)
				f[4].options[2].disabled=1;
			if (nvram.lan3_ifname.length < 1)
				f[4].options[3].disabled=1;

			f[4].selectedIndex = 4;
			ferror.clearAll(fields.getAll(this.newEditor));
		}

		wlg.verifyFields = function(row, quiet) {
			var ok = 1;
			var f = fields.getAll(row);

			if (nvram.lan_ifname.length < 1)
				f[4].options[0].disabled=1;
			if (nvram.lan1_ifname.length < 1)
				f[4].options[1].disabled=1;
			if (nvram.lan2_ifname.length < 1)
				f[4].options[2].disabled=1;
			if (nvram.lan3_ifname.length < 1)
				f[4].options[3].disabled=1;

			if (f[0].value.indexOf('.') < 0) {
				/* REMOVE-BEGIN */
				//		fields.disableAll(row, 1);
				//		return 1;
				/* REMOVE-END */
			} else {
				for(var i = 0; i < f[3].options.length ; i++) {
					/* REMOVE-BEGIN */
					//			f[3].options[i].disabled = ((f[3].options[i].value != 'ap') && (f[3].options[i].value != 'wet'));
					/* REMOVE-END */
					f[3].options[i].disabled = (f[3].options[i].value != 'ap');
				}

			}
			/* REMOVE-BEGIN */
			// AB: user can't change WLIF name on gridObj, only by deleting/adding WLIf (destroying/recreating)
			/* REMOVE-END */
			if (this.isEditing())
				f[0].disabled = 1;

			for(var i=0; i < f[0].options.length ; i++) {
				f[0].options[i].disabled = (this.countVIF(f[0].options[i].value) > 0);
			}

			if (!v_length(f[2], quiet || !ok, 1, 32)) ok = 0;

			return ok;
		}

		wlg.dataToView = function(data) {
			var ifname, uidx, ssid;
			uidx = wl_ifidxx(data[0]);
			if (uidx < 0) {
				ifname = 'wl' + data[0];
			} else {
				ifname = wl_ifaces[uidx][0] + ((wl_sunit(uidx) < 0) ? ' (wl' + wl_fface(uidx) + ')' : '');
			}
			ssid = data[2];

			return ([ifname,
				(data[1] == 1) ? '<% translate("Yes"); %>' : '<% translate("No"); %>',
				ssid || '<small><i>(<% translate("unset"); %>)</i></small>',
				wmo[data[3]] || '<small><i>(<% translate("unset"); %>)</i></small>',
				['<% translate("LAN"); %> (br0)', '<% translate("LAN2"); %> (br1)', '<% translate("LAN3"); %> (br2)', '<% translate("LAN4"); %> (br3)', '<% translate("none"); %>' ][data[4]]
			]);
		}

		wlg.dataToFieldValues = function (data) {
			return ([data[0],
				(data[1] == '1') ? 'checked' : '',
				data[2],
				data[3],
				data[4]
			]);
		}

		wlg.fieldValuesToData = function(row) {
			var f = fields.getAll(row);
			return ([f[0].value,
				f[1].checked ? '1' : '0',
				f[2].value,
				f[3].value,
				f[4].value
			]);
		}

		wlg.onDelete = function() {
			this.removeEditor();
			if (this.source._data[0].indexOf('.') > 0) {
				var vif = definedVIFidx(this.source._data[0]);
				vifs_defined.splice(vif,1);
				vifs_deleted.push(this.source._data[0]);
				elem.remove(this.source);
				this.source = null;
			} else {
				this.showSource();
			}
			this.disableNewEditor(false);
			this.resetNewEditor();
		}

		wlg.onCancel = function() {
			this.removeEditor();
			this.showSource();
			this.disableNewEditor(false);
			this.resetNewEditor();
		}

		wlg.onAdd = function() {
			var data, u, wmode;

			this.moving = null;
			this.rpHide();

			if (!this.verifyFields(this.newEditor, false)) return;

			data = this.fieldValuesToData(this.newEditor);
			this.insertData(-1, data);

			u = data[0].toString();
			E('_f_wl'+u+'_radio').checked = (data[1] == '1');
			E('_wl'+u+'_ssid').value = data[2];
			E('_f_wl'+u+'_mode').value = data[3];

			vifs_defined.push([
				u.toString(),						// fface == wl_ifaces[uidx][1]
				(nvram['wl' + u + '_ifname']) || ('wl'+u),	// ifname =~ wl_ifaces[uidx][0]
				u.substr(0, u.indexOf('.')),		// unit
				u.substr(u.indexOf('.')+1) || '-1',	// subunit
				data[1] || '1',						// radio
				'0',								// iface up?
				data[1] || '1',						// bss_enabled
				data[3],							// WL net mode
				data[2], 							// nvram['wl' + u + '_ssid'],
				(eval('nvram["wl'+u+'_hwaddr"]')) || '00:00:00:00:00:00',		// MAC addr
				'0',								// VIFs supported
				data[4]
			]);

			this.resort();

			this.disableNewEditor(false);
			this.resetNewEditor();

			/* if we had previously deleted this entry, remove it from deleted table */
			for (var i = 0; i < vifs_deleted.length; i++) {
				if (vifs_deleted[i] == u) {
					vifs_deleted.splice(i, 1);
					break;
				}
			}

			tabSelect(u);
			verifyFields(null,1);

			var e = E('footer-msg');
			e.innerHTML = '<% translate("After configuring this VIF, review and save your settings on the Overview tab"); %>.';
			e.style.visibility = 'visible';
			/* REMOVE-BEGIN */
			//	setTimeout(
			//		function() {
			//		e.innerHTML = '';
			//		e.style.visibility = 'hidden';
			//		}, 5000);
			/* REMOVE-END */
		}

		wlg.onOK = function() {
			//TODO: update info on VIF tab
			//	var i, data, view, e, u;
			var i, data, view, u;

			if (!this.verifyFields(this.editor, false)) return;

			data = this.fieldValuesToData(this.editor);
			view = this.dataToView(data);

			u = data[0].toString();

			E('_f_wl'+u+'_radio').checked = (data[1] == '1');
			E('_wl'+u+'_ssid').value = data[2];
			E('_f_wl'+u+'_mode').value = data[3];

			var vif = definedVIFidx(u);
			/* REMOVE-BEGIN */
			//	vifs_defined[vif][4] = data[1]; // radio
			//	vifs_defined[vif][6] = data[2]; // bss_enabled
			//	vifs_defined[vif][8] = data[3]; // SSID
			//	vifs_defined[vif][7] = data[4]; // WL mode
			/* REMOVE-END */
			vifs_defined[vif][4] = data[1]; // radio
			/* REMOVE-BEGIN */
			//	vifs_defined[vif][6] = data[2]; // bss_enabled
			/* REMOVE-END */
			vifs_defined[vif][8] = data[2]; // SSID
			vifs_defined[vif][7] = data[3]; // WL mode
			vifs_defined[vif][11] = data[4]; // LAN bridge
			/* REMOVE-BEGIN */
			//alert(data.join('\n'));
			/* REMOVE-END */

			this.source.setRowData(data);
			for (i = 0; i < this.source.cells.length; ++i) {
				this.source.cells[i].innerHTML = view[i];
			}

			this.removeEditor();
			this.showSource();
			this.disableNewEditor(false);
			this.resetNewEditor();

			verifyFields(null,1);
		}

		wlg.countElem = function(f, v) {
			var data = this.getAllData();
			var total = 0;
			for (var i = 0; i < data.length; ++i) {
				total += (data[i][f] == v) ? 1 : 0;
			}
			return total;
		}

		wlg.countVIF = function (v) {
			return this.countElem(0,v);
		}

		function earlyInit() {

			for (var mode in wmo) {
				wl_modes_available.push([mode, wmo[mode]]);
			}
			/* REMOVE-BEGIN */
			//	for (var mode in auth) {
			//		wl_sec_modes_available.push([mode, auth[mode]]);
			//	}
			//	for (var mode in enc) {
			//		wl_enc_modes_available.push([mode, enc[mode]]);
			//	}

			//wl_ifaces = [ ['eth1','0',0,-1,'bott','00:1C:10:9E:8C:8E',1,4],['wl0.1','0.1',0,1,'ghetto','02:1C:10:9E:8C:8F',1,0],
			//				['eth2','1',1,-1,'lixo','04:1C:10:9E:8C:8E',1,4]];
			//wl_bands = [ [ '2'],[ '2'],[ '2'] ];
			/* REMOVE-END */

			for (var uidx = 0; uidx < wl_ifaces.length; ++uidx) {
				var u = wl_fface(uidx).toString();
				var bridged = 4;
				if (u) {
					var wmode = (((nvram['wl' + u + '_mode']) == 'ap') && ((nvram['wl' + u + '_wds_enable']) == '1')) ? 'apwds': (nvram['wl' + u + '_mode']);

					for (var i = 0 ; i <= MAX_BRIDGE_ID ; i++) {
						var j = (i == 0) ? '' : i.toString();
						var l = nvram['lan' + j + '_ifnames'].split(' ');
						for (var k = 0 ; k < l.length; k++) {
							if(l[k].indexOf(wl_ifaces[uidx][0]) != -1) {
								bridged = i;
							}
						}
					}

					var wlvifs = ((wl_ifaces[uidx][7] > 4) ? '4' : wl_ifaces[uidx][7].toString());
					vifs_defined.push([
						u.toString(),						// fface == wl_ifaces[uidx][1]
						wl_ifaces[uidx][0],
						//			(nvram['wl' + u + '_ifname']) || ('wl'u),	// ifname =~ wl_ifaces[uidx][0]
						wl_ifaces[uidx][2] || '0',			// unit
						wl_ifaces[uidx][3] || '0',			// subunit
						nvram['wl' + u + '_radio'] || '0',	// radio
						wl_ifaces[uidx][6] || '0',			// iface up/operational status
						nvram['wl' + u + '_bss_enabled'] || '1',	// bss_enabled
						wmode || 'disabled',				// WL net mode
						wl_ifaces[uidx][4] || '',			// nvram['wl' + u + '_ssid'],
						//			wl_ifaces[uidx][4], 				// nvram['wl' + u + '_ssid'],
						nvram['wl' + u + '_hwaddr'],		// MAC addr
						//				(wl_ifaces[uidx][7] * 1).toString(), // VIFs supported
						wlvifs,								// VIFs supported
						bridged
					]);
					//			max_no_vifs = max_no_vifs + ((wl_ifaces[uidx][7] > 4) ? 4 : wl_ifaces[uidx][7]);
					max_no_vifs = max_no_vifs + parseInt(wlvifs);
				}
			}

			W('<style type=\'text/css\'>');
			for (var uidx in vifs_defined) {
				if (typeof(vifs_defined[uidx][0]) == 'undefined') continue;

				var total = vifs_defined[uidx][10] * 1;
				if (isNaN(total)) continue;
				if (total >= 4) total = 4;

				W('#spin'+vifs_defined[uidx][2]+', ');

				for (var i = 0; i < total; ++i) {
					var u = vifs_defined[uidx][2].toString();
					var s = (i == 0) ? '' : '.' + i.toString();
					var t = u + s;
					var v = wl_ifidxx(t);
					var w = (v < 0) ? ('wl' + t) : (wl_ifaces[v][0] + ((wl_sunit(v) < 0) ? ' (wl' + t + ')' : ''));
					vifs_possible.push([ t, w ]);
					tabs.push([ t, w ]);
				}
			}

			W('#spin {');
			W('	visibility: hidden;');
			W('	vertical-align: middle;');
			W('}');
			W('</style>');

		}

		function init() {

			var uninit = wl_ifaces.length - 1;
			while (uninit > 0) {
				if (((nvram['wl' + wl_unit(uninit) + '_corerev']) *1) >= 9) break;
				uninit--;
			}

			E('sesdiv').style.display = '';
			if (uninit < 0) {
				E('sesdiv').innerHTML = '<i><% translate("This feature is not supported on this router"); %>.</i>';
				return;
			}

			tabSelect(cookie.get('advanced_wlanvifs_tab') || tabs[0][0]);

			var c;

			if (((c = cookie.get('adv_wlvifs_notes_vis')) != null) && (c == '1')) {
				toggleVisibility("notes");
			}

			if (((c = cookie.get('adv_wlvifs_details_vis')) != null) && (c == '1')) {
				toggleVisibility("details");
			}
			/* LINUX24-BEGIN */
			if (((c = cookie.get('adv_wlvifs_options_vis')) != null) && (c == '1')) {
				toggleVisibility("options");
			}
			/* LINUX24-END */

			wlg.setup();
		}

		function toggleVisibility(whichone) {
			if(E('sesdiv_' + whichone).style.display=='') {
				E('sesdiv_' + whichone).style.display='none';
				E('sesdiv_' + whichone + '_showhide').innerHTML='<i class="icon-chevron-up"></i>';
				cookie.set('adv_wlvifs_' + whichone + '_vis', 0);
			} else {
				E('sesdiv_' + whichone).style.display='';
				E('sesdiv_' + whichone + '_showhide').innerHTML='<i class="icon-chevron-down"></i>';
				cookie.set('adv_wlvifs_' + whichone + '_vis', 1);
			}
		}

		function definedVIFidx(vif) {
			for (var i = 0; i < vifs_defined.length; ++i)
			if (vifs_defined[i][0] == vif) return i;
			return -1;
		}

		function tabSelect(name) {
			if (wlg.isEditing()) return;

			tgHideIcons();

			tabHigh(name);

			if (!E('save-button').disabled) E('footer-msg').style.visibility = 'hidden';

			if (name == 'overview') {
				wlg.populate();
			}

			elem.display('overview-tab', (name == 'overview'));
			E('save-button').value = (name != 'overview') ? '<% translate("Overview"); %>' : '<% translate("Save"); %>';

			for (var i = 1; i < tabs.length; ++i) {
				if (name == tabs[i][0]) {
					if (definedVIFidx(name) < 0) {
						elem.display(tabs[i][0] + '-tab-disabled', 1);
						elem.display(tabs[i][0] + '-tab', 0);
					} else {
						elem.display(tabs[i][0] + '-tab-disabled', 0);
						elem.display(tabs[i][0] + '-tab', 1);
					}
				} else {
					elem.display(tabs[i][0] + '-tab', 0);
					elem.display(tabs[i][0] + '-tab-disabled', 0);
				}
			}

			cookie.set('advanced_wlanvifs_tab', name);
		}

		function verifyFields(focused, quiet) {
			var i;
			var ok = 1;
			var a, b, c, d, e;
			var u, uidx;
			var wmode, sm2;

			for (uidx = 0; uidx < wl_ifaces.length; ++uidx) {
				u = wl_fface(uidx);
				if (u)
					E('wl'+u+'_hwaddr_msg').style.visibility = ((wl_ifaces[uidx][8] == 'ap') && (wl_ifaces[uidx][5] != wl_ifaces[uidx][9])) ? 'visible' : 'hidden';
				if (wl_sunit(uidx) < 0) {
					if (focused == E('_f_wl'+u+'_nband')) {
						refreshNetModes(uidx);
						refreshChannels(uidx);
					}
					else if (focused == E('_f_wl'+u+'_nctrlsb') || focused == E('_wl'+u+'_nbw_cap')) {
						refreshChannels(uidx);
					}
				}
			}

			var wl_vis = [];
			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0];
				if (definedVIFidx(u) < 0) continue;

				if (u.toString().indexOf('.') < 0) {
					var uidx = wl_ifidxx(u);
					a = {
						_f_wl_radio: 1,
						_f_wl_mode: 1,
						// AB disabled for VIFs?!
						_f_wl_nband: (bands[uidx].length > 1) ? 1 : 0,
						// AB disabled for VIFs?!
						_wl_net_mode: 1,
						_wl_ssid: 1,
						_f_wl_bcast: 1,
						// AB disabled for VIFs?!
						_wl_channel: 1,
						// AB disabled for VIFs?!
						_wl_nbw_cap: nphy ? 1 : 0,
						// AB disabled for VIFs?!
						_f_wl_nctrlsb: nphy ? 1 : 0,
						// AB disabled for VIFs?!
						_f_wl_scan: 1,

						_wl_security_mode: 1,
						_wl_crypto: 1,
						_wl_wpa_psk: 1,
						_f_wl_psk_random1: 1,
						_f_wl_psk_random2: 1,
						_wl_wpa_gtk_rekey: 1,
						_wl_radius_key: 1,
						_wl_radius_ipaddr: 1,
						_wl_radius_port: 1,
						_wl_wep_bit: 1,
						_wl_passphrase: 1,
						_f_wl_wep_gen: 1,
						_f_wl_wep_random: 1,
						_wl_key1: 1,
						_wl_key2: 1,
						_wl_key3: 1,
						_wl_key4: 1,

						_f_wl_lazywds: 1,
						_f_wl_wds_0: 1
					};
				} else {
					a = {
						_f_wl_radio: 1,
						_f_wl_mode: 1,
						/* REMOVE-BEGIN */
						// AB disabled for VIFs?!
						//			_f_wl_nband: (bands[uidx].length > 1) ? 1 : 0,
						// AB disabled for VIFs?!
						//			_wl_net_mode: 1,
						/* REMOVE-END */
						_wl_ssid: 1,
						_f_wl_bcast: 1,
						/* REMOVE-BEGIN */
						// AB disabled for VIFs?!
						//			_wl_channel: 1,
						//			_wl_nbw_cap: nphy ? 1 : 0,
						//			_f_wl_nctrlsb: nphy ? 1 : 0,
						//			_f_wl_scan: 1,
						/* REMOVE-END */

						_wl_security_mode: 1,
						_wl_crypto: 1,
						_wl_wpa_psk: 1,
						_f_wl_psk_random1: 1,
						_f_wl_psk_random2: 1,
						_wl_wpa_gtk_rekey: 1,
						_wl_radius_key: 1,
						_wl_radius_ipaddr: 1,
						_wl_radius_port: 1,
						_wl_wep_bit: 1,
						_wl_passphrase: 1,
						_f_wl_wep_gen: 1,
						_f_wl_wep_random: 1,
						_wl_key1: 1,
						_wl_key2: 1,
						_wl_key3: 1,
						_wl_key4: 1,

						_f_wl_lazywds: 1,
						_f_wl_wds_0: 1
					};
				}
				wl_vis[vidx] = a;
			}

			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0];
				if (definedVIFidx(u) < 0) continue;

				wmode = E('_f_wl'+u+'_mode').value;

				if (!E('_f_wl'+u+'_radio').checked) {
					for (a in wl_vis[vidx]) {
						wl_vis[vidx][a] = 2;
					}
					wl_vis[vidx]._f_wl_radio = 1;
					if (u.toString().indexOf('.') < 0) {
						var uidx = wl_ifidxx(u);
						wl_vis[vidx]._wl_nbw_cap = nphy ? 2 : 0;
						wl_vis[vidx]._f_wl_nband = (bands[uidx].length > 1) ? 2 : 0;
					}
				}

				E('wl'+u+'_mode_msg').style.visibility = ((wmode == 'sta') || (wmode == 'wet')) ? 'visible' : 'hidden';

				switch (wmode) {
					case 'apwds':
					case 'wds':
						break;
					case 'wet':
					case 'sta':
						wl_vis[vidx]._f_wl_bcast = 0;
						if (u.toString().indexOf('.') < 0) {
							wl_vis[vidx]._wl_channel = 0;
							wl_vis[vidx]._wl_nbw_cap = 0;
						}
					default:
					wl_vis[vidx]._f_wl_lazywds = 0;
					wl_vis[vidx]._f_wl_wds_0 = 0;
					break;
				}

				sm2 = E('_wl'+u+'_security_mode').value;
				switch (sm2) {
					case 'disabled':
						wl_vis[vidx]._wl_crypto = 0;
						wl_vis[vidx]._wl_wep_bit = 0;
						wl_vis[vidx]._wl_wpa_psk = 0;
						wl_vis[vidx]._wl_radius_key = 0;
						wl_vis[vidx]._wl_radius_ipaddr = 0;
						wl_vis[vidx]._wl_wpa_gtk_rekey = 0;
						break;
					case 'wep':
						wl_vis[vidx]._wl_crypto = 0;
						wl_vis[vidx]._wl_wpa_psk = 0;
						wl_vis[vidx]._wl_radius_key = 0;
						wl_vis[vidx]._wl_radius_ipaddr = 0;
						wl_vis[vidx]._wl_wpa_gtk_rekey = 0;
						break;
					case 'radius':
						wl_vis[vidx]._wl_crypto = 0;
						wl_vis[vidx]._wl_wpa_psk = 0;
						break;
					default:	// wpa*
						wl_vis[vidx]._wl_wep_bit = 0;
						if (sm2.indexOf('personal') != -1) {
							wl_vis[vidx]._wl_radius_key = 0;
							wl_vis[vidx]._wl_radius_ipaddr = 0;
						}
						else {
							wl_vis[vidx]._wl_wpa_psk = 0;
						}
						break;
				}

				if ((E('_f_wl'+u+'_lazywds').value == 1) && (wl_vis[vidx]._f_wl_wds_0 == 1)) {
					wl_vis[vidx]._f_wl_wds_0 = 2;
				}

				if (u.toString().indexOf('.') < 0) {
					if (wl_vis[vidx]._wl_nbw_cap != 0) {
						switch (E('_wl'+u+'_net_mode').value) {
							case 'b-only':
							case 'g-only':
							case 'a-only':
							case 'bg-mixed':
								wl_vis[vidx]._wl_nbw_cap = 2;
								if (E('_wl'+u+'_nbw_cap').value != '0') {
									E('_wl'+u+'_nbw_cap').value = 0;
									refreshChannels(wl_ifidxx(u));
								}
								break;
						}
						// avoid Enterprise-TKIP with 40MHz
						if ((sm2 == 'wpa_enterprise') && (E('_wl'+u+'_crypto').value == 'tkip')) {
							wl_vis[vidx]._wl_nbw_cap = 2;
							if (E('_wl'+u+'_nbw_cap').value != '0') {
								E('_wl'+u+'_nbw_cap').value = 0;
								/* REMOVE-BEGIN */
								//						refreshChannels(uidx);
								/* REMOVE-END */
								refreshChannels(wl_ifidxx(u));
							}
						}
					}
					wl_vis[vidx]._f_wl_nctrlsb = (E('_wl'+u+'_nbw_cap').value == 0) ? 0 : wl_vis[vidx]._wl_nbw_cap;

					/* REMOVE-BEGIN
					This is ugly...
					Special case - 2.4GHz band, currently running in B/G-only mode,
					with N/Auto and 40MHz selected in the GUI.
					Channel list is not filtered in this case by the wl driver,
					and includes all channels available with 20MHz channel width.
					REMOVE-END */

					/* REMOVE-BEGIN */
					//			b = selectedBand(uidx);
					/* REMOVE-END */
					b = selectedBand(wl_ifidxx(u));

					if (wl_vis[vidx]._wl_channel == 1 && wl_vis[vidx]._f_wl_nctrlsb != 0 &&
						((b == '2') || (wl_vis[vidx]._f_wl_nband == 0 && b == '0'))) {
						switch (eval('nvram["wl'+u+'_net_mode"]')) {
							case 'b-only':
							case 'g-only':
							case 'bg-mixed':
								i = E('_wl'+u+'_channel').value * 1;
								if (i > 0 && i < 5) {
									E('_f_wl'+u+'_nctrlsb').value = 'lower';
									wl_vis[vidx]._f_wl_nctrlsb = 2;
								}
								/* REMOVE-BEGIN */
								//					else if (i > max_channel[uidx] - 4) {
								/* REMOVE-END */
								else if (i > max_channel[wl_ifidxx(u)] - 4) {
									E('_f_wl'+u+'_nctrlsb').value = 'upper';
									wl_vis[vidx]._f_wl_nctrlsb = 2;
								}
								break;
						}
					}
					wl_vis[vidx]._f_wl_scan = wl_vis[vidx]._wl_channel;
				} else {

					e = E('_f_wl'+u+'_mode');
					for(var i = 0; i < e.options.length ; i++) {
						/* REMOVE-BEGIN */
						//				e.options[i].disabled = ((e.options[i].value != 'ap') && (e.options[i].value != 'wet'));
						/* REMOVE-END */
						e.options[i].disabled = (e.options[i].value != 'ap');
					}
				}

				wl_vis[vidx]._f_wl_psk_random1 = wl_vis[vidx]._wl_wpa_psk;
				wl_vis[vidx]._f_wl_psk_random2 = wl_vis[vidx]._wl_radius_key;
				wl_vis[vidx]._wl_radius_port = wl_vis[vidx]._wl_radius_ipaddr;
				wl_vis[vidx]._wl_key1 = wl_vis[vidx]._wl_key2 = wl_vis[vidx]._wl_key3 = wl_vis[vidx]._wl_key4 = wl_vis[vidx]._f_wl_wep_gen = wl_vis[vidx]._f_wl_wep_random = wl_vis[vidx]._wl_passphrase = wl_vis[vidx]._wl_wep_bit;

				for (i = 1; i < 10; ++i) {
					wl_vis[vidx]['_f_wl_wds_' + i] = wl_vis[vidx]._f_wl_wds_0;
				}

			} // for each wl_iface

			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0];
				if (definedVIFidx(u) < 0) continue;
				for (a in wl_vis[vidx]) {
					i = 3;
					if (a.substr(0, 6) == '_f_wl_') i = 5;
					b = E(a.substr(0, i) + u + a.substr(i, a.length));
					if (b == null) { continue; }
					c = wl_vis[vidx][a];
					b.disabled = (c != 1);
					PR(b).style.display = c ? '' : 'none';
				}
			}

			// --- verify ---

			var wlclnt = 0;
			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0];
				if (definedVIFidx(u) < 0) continue;

				wmode = E('_f_wl'+u+'_mode').value;
				sm2 = E('_wl'+u+'_security_mode').value;

				// --- N standard does not support WPA+TKIP ---
				if (u.toString().indexOf('.') < 0) {
					a = E('_wl'+u+'_crypto');
					switch (E('_wl'+u+'_net_mode').value) {
						case 'mixed':
						case 'n-only':
							if (nphy && (a.value == 'tkip') && (sm2.indexOf('wpa') != -1)) {
								ferror.set(a, '<% translate("TKIP encryption is not supported with WPA / WPA2 in N mode"); %>.', quiet || !ok);
								ok = 0;
							}
							else ferror.clear(a);
							break;
					}

					a = E('_wl'+u+'_net_mode');
					ferror.clear(a);
				}

				b = E('_f_wl'+u+'_mode');
				ferror.clear(b);

				if ((wmode == 'sta') || (wmode == 'wet')) {
					++wlclnt;
					if (wlclnt > 1) {
						ferror.set(b, '<% translate("Only one wireless interface can be configured in client mode"); %>.', quiet || !ok);
						ok = 0;
					}
					else if (a.value == 'n-only') {
						ferror.set(a, '<% translate("N-only is not supported in wireless client modes, use Auto"); %>.', quiet || !ok);
						ok = 0;
					}
				}

				a = E('_wl'+u+'_wpa_psk');
				ferror.clear(a);
				if (wl_vis[vidx]._f_wl_wpa_psk == 1) {
					if ((a.value.length < 8) || ((a.value.length == 64) && (a.value.search(/[^0-9A-Fa-f]/) != -1))) {
						ferror.set('_wl'+u+'_wpa_psk', '<% translate("Invalid pre-shared key. Please enter at least 8 characters or 64 hexadecimal digits"); %>.', quiet || !ok);
						ok = 0;
					}
				}

				if (u.toString().indexOf('.') < 0) {
					// wl channel
					if (((wmode == 'wds') || (wmode == 'apwds')) && (wl_vis[vidx]._wl_channel == 1) && (E('_wl'+u+'_channel').value == '0')) {
						ferror.set('_wl'+u+'_channel', '<% translate("Fixed wireless channel required in WDS mode"); %>.', quiet || !ok);
						ok = 0;
					}
					else ferror.clear('_wl'+u+'_channel');
				}
				/* REMOVE-BEGIN */
				/*
				if (E('_f_wl'+u+'_mode').value == 'sta') {
				if ((wan == 'disabled') && (E('_f_wl'+u+'_radio').checked)) {
				ferror.set('_wan_proto', 'Wireless Client mode requires a valid WAN setting (usually DHCP).', quiet || !ok);
				ok = 0;
				}
				}
				*/
				/* REMOVE-END */
			}

			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0];
				if (definedVIFidx(u) < 0) continue;

				// IP address
				a = ['_radius_ipaddr'];
				for (i = a.length - 1; i >= 0; --i) {
					if ((wl_vis[vidx]['_wl'+a[i]]) && (!v_ip('_wl'+u+a[i], quiet || !ok))) ok = 0;
				}

				// range
				a = [['_wpa_gtk_rekey', 60, 7200], ['_radius_port', 1, 65535]];
				for (i = a.length - 1; i >= 0; --i) {
					v = a[i];
					if ((wl_vis[vidx]['_wl'+v[0]]) && (!v_range('_wl'+u+v[0], quiet || !ok, v[1], v[2]))) ok = 0;
				}

				// length
				a = [['_ssid', 1], ['_radius_key', 1]];
				for (i = a.length - 1; i >= 0; --i) {
					v = a[i];
					if ((wl_vis[vidx]['_wl'+v[0]]) && (!v_length('_wl'+u+v[0], quiet || !ok, v[1], E('_wl'+u+v[0]).maxlength))) ok = 0;
				}

				if (wl_vis[vidx]._wl_key1) {
					a = (E('_wl'+u+'_wep_bit').value == 128) ? 26 : 10;
					for (i = 1; i <= 4; ++i) {
						b = E('_wl'+u+'_key' + i);
						b.maxLength = a;
						if ((b.value.length > 0) || (E('_f_wl'+u+'_wepidx_' + i).checked)) {
							if (!v_wep(b, quiet || !ok)) ok = 0;
						}
						else ferror.clear(b);
					}
				}

				ferror.clear('_f_wl'+u+'_wds_0');
				if (wl_vis[vidx]._f_wl_wds_0 == 1) {
					b = 0;
					for (i = 0; i < 10; ++i) {
						a = E('_f_wl'+u+'_wds_' + i);
						if (!v_macz(a, quiet || !ok)) ok = 0;
						else if (!isMAC0(a.value)) b = 1;
					}
					if (!b) {
						ferror.set('_f_wl'+u+'_wds_0', '<% translate("WDS MAC address required"); %>.', quiet || !ok);
						ok = 0;
					}
				}

				if ((ok) && (focused)) {
					var w = definedVIFidx(u);
					if (focused.id == '_wl'+u+'_ssid') {
						vifs_defined[w][8] = focused.value;
					}
					if (focused.id == '_f_wl'+u+'_mode') {
						vifs_defined[w][7] = focused.value;
					}
					if (focused.id == '_f_wl'+u+'_radio') {
						vifs_defined[w][4] = (focused.checked) ? '1' : '0';
						vifs_defined[w][6] = (focused.checked) ? '1' : '0';
					}
				}

			}

			return ok;
		}

		function cancel() {
			cookie.set('advanced_wlanvifs_tab', 'overview');
			javascript:reloadPage();
		}

		function save() {
			if (E('save-button').value != '<% translate("Save"); %>') {
				tabSelect('overview');
				return;
			}

			if (wlg.isEditing()) return;
			wlg.resetNewEditor();
			if (!verifyFields(null, false)) return;

			var a, b, c;
			var w, uidx, wmode, sm2, wradio;

			var i, u, vidx, vif;

			var fom = E('_fom');
			/* LINUX24-BEGIN */
			fom.nas_alternate.value = E('_f_nas_alternate').checked ? '1' : '0';
			/* LINUX24-END */

			for (var i = 0 ; i <= MAX_BRIDGE_ID ; i++) {
				var j = (i == 0) ? '' : i.toString();
				fom['lan'+j+'_ifnames'].value = '';
				var l = nvram['lan' + j + '_ifnames'].split(' ');
				for (var k = 0 ; k < l.length; ++k) {
					if(l[k].indexOf('vlan') != -1) {
						fom['lan'+j+'_ifnames'].value += l[k] + ' ';
					}
				}
				fom['lan'+j+'_ifnames'].value = fom['lan'+j+'_ifnames'].value.trim();
			}

			for (vidx = 0; vidx < vifs_possible.length; ++vidx) {
				u = vifs_possible[vidx][0].toString();  // WL unit (primary) or unit.subunit (virtual)
				vif = definedVIFidx(u);

				/* REMOVE-BEGIN */
				// AB TODO: try to play this safer - save some vital info on primary BSS (just in case?)
				// AB TODO: with the UNSET part later on - is this really needed?
				/* REMOVE-END */
				if (vif < 0) {
					a = [ ['radio', '0'], ['bss_enabled', '0'], ['ifname', ('wl'+u)] ];
					b = 'wl'+u+'_';
					for (i = 0; i < a.length; ++i) {
						c = '' + b + a[i][0];
						if (typeof(nvram[c]) != 'undefined')
							E('_'+c).value = a[i][1];
					}
					continue;
				}

				if (vifs_defined[vif][11]*1 != 4) {
					var x = (vifs_defined[vif][11] == '0') ? '' : vifs_defined[vif][11].toString();
					fom['lan'+x+'_ifnames'].value += ' ' + vifs_defined[vif][1];
					fom['lan'+x+'_ifnames'].value = fom['lan'+x+'_ifnames'].value.trim();
				}

				/* REMOVE-BEGIN */
				// AB TODO: cleanup in advance or just bail out later?
				/* REMOVE-END */
				if (u.indexOf('.') < 0) {
					a = [];
					for (i = 0; i < vifs_defined.length; ++i) {
						if (vifs_defined[i][2].toString() != u) continue;
						if ((vifs_defined[i][3] * 1) < 1) continue;
						a.push('wl'+vifs_defined[i][0]);
					}
					E('_wl'+u+'_vifs').value = a.join(' ');
					E('_wl'+u+'_ifname').value = nvram['wl'+u+'_ifname'] || vifs_defined[vif][1];
				} else {
					E('_wl'+u+'_ifname').value = nvram['wl'+u+'_ifname'] || 'wl'+u;
				}

				wmode = E('_f_wl'+u+'_mode').value;
				sm2 = E('_wl'+u+'_security_mode').value;
				wradio = E('_f_wl'+u+'_radio').checked;

				if (wmode == 'apwds') E('_wl'+u+'_mode').value = 'ap';
				else E('_wl'+u+'_mode').value = wmode;

				/* REMOVE-BEGIN */
				// primary VIF
				/* REMOVE-END */
				if (u.indexOf('.') < 0) {
					E('_wl'+u+'_nband').value = selectedBand(wl_ifidxx(u));

					a = [];
					for (i = 0; i < 10; ++i) a.push(E('_f_wl'+u+'_wds_' + i).value);
					E('_wl'+u+'_wds').value = joinAddr(a);

					if (wmode.indexOf('wds') != -1) {
						E('_wl'+u+'_wds_enable').value = 1;
						E('_wl'+u+'_lazywds').value = E('_f_wl'+u+'_lazywds').value;
						if (E('_wl'+u+'_lazywds').value == 1) E('_wl'+u+'_wds').value = '';
					}
					else {
						E('_wl'+u+'_wds_enable').value = 0;
						E('_wl'+u+'_wds').value = '';
						E('_wl'+u+'_lazywds').value = 0;
					}
				}

				E('_wl'+u+'_radio').value = wradio ? 1 : 0;
				E('_wl'+u+'_bss_enabled').value = wradio ? 1 : 0;

				E('_wl'+u+'_auth').value = eval('nvram["wl'+u+'_auth"]') || '0';

				e = E('_wl'+u+'_akm');
				switch (sm2) {
					case 'disabled':
					case 'radius':
					case 'wep':
						e.value = '';
						break;
					default:
						c = [];

						if (sm2.indexOf('personal') != -1) {
							if (sm2.indexOf('wpa2_') == -1) c.push('psk');
							if (sm2.indexOf('wpa_') == -1) c.push('psk2');
						}
						else {
							if (sm2.indexOf('wpa2_') == -1) c.push('wpa');
							if (sm2.indexOf('wpa_') == -1) c.push('wpa2');
						}
						c = c.join(' ');
						e.value = c;
						break;
				}
				E('_wl'+u+'_auth_mode').value = (sm2 == 'radius') ? 'radius' : 'none';
				E('_wl'+u+'_wep').value = ((sm2 == 'radius') || (sm2 == 'wep')) ? 'enabled': 'disabled';

				if (sm2.indexOf('wpa') != -1) E('_wl'+u+'_auth').value = '0';

				/* REMOVE-BEGIN */
				//  primary VIF
				/* REMOVE-END */
				if (u.indexOf('.') < 0) {

					E('_wl'+u+'_nreqd').value = 0;
					E('_wl'+u+'_gmode').value = 1;
					E('_wl'+u+'_nmode').value = 0;
					E('_wl'+u+'_nmcsidx').value = -2; // Legacy Rate
					E('_wl'+u+'_nbw').value = 0;
					switch (E('_wl'+u+'_net_mode').value) {
						case 'b-only':
							E('_wl'+u+'_gmode').value = 0;
							break;
						case 'g-only':
							E('_wl'+u+'_gmode').value = 4;
							break;
						case 'bg-mixed':
							break;
						case 'a-only':
							E('_wl'+u+'_nmcsidx').value = -1; // Auto
							break;
						case 'n-only':
							if (selectedBand(wl_ifidxx(u)) == '1') { // 5 GHz
								E('_wl'+u+'_nmode').value = -1;
								E('_wl'+u+'_nmcsidx').value = -1;
							} else {
								E('_wl'+u+'_nmode').value = 1;
								E('_wl'+u+'_nmcsidx').value = 32;
							}
							E('_wl'+u+'_nreqd').value = 1;
							break;
						default: // Auto
							E('_wl'+u+'_nmode').value = -1;
							E('_wl'+u+'_nmcsidx').value = -1;
							break;
					}

					E('_wl'+u+'_nctrlsb').value = eval('nvram.wl'+u+'_nctrlsb');
					if (E('_wl'+u+'_nmode').value != 0) {
						E('_wl'+u+'_nctrlsb').value = E('_f_wl'+u+'_nctrlsb').value;
						E('_wl'+u+'_nbw').value = (E('_wl'+u+'_nbw_cap').value == 0) ? 20 : 40;
					}
				}

				E('_wl'+u+'_closed').value = E('_f_wl'+u+'_bcast').checked ? 0 : 1;

				a = fields.radio.selected(eval('fom["f_wl'+u+'_wepidx"]'));
				/* REMOVE-BEGIN */
				//		if (a) E('_wl'+u+'_key').value = a.value;
				/* REMOVE-END */
				E('_wl'+u+'_key').value = (a) ? a.value : '1';
			}

			do_pre_submit_form(fom);

			/* REMOVE-BEGIN */
			//	form.submit(fom,1);
			/* REMOVE-END */
		}

		function submit_complete() {
			reloadPage();
		}


		var cmdresult = '';
		var cmd = null;

		function do_pre_submit_form(fom) {

			var footermsg = E('footer-msg');
			footermsg.innerHTML = '<% translate("Saving"); %>...';
			footermsg.style.visibility = 'visible';

			E('save-button').disabled = 1;
			E('cancel-button').disabled = 1;

			var elem = fom.elements;

			var s = '';

			for (var vidx = 0; vidx < vifs_possible.length; ++vidx) {
				var u = vifs_possible[vidx][0].toString();  // WL unit (primary) or unit.subunit (virtual)
				if (u.indexOf('.') > 0) { // only if virtual VIF
					var vif = definedVIFidx(u);
					if (vif >= 0)
					{
						for (var i = 0; i < elem.length ; ++i) {
							if (elem[i].name.indexOf('wl' + u) == 0) {
								s += 'nvram set ' + elem[i].name + '=\'' + elem[i].value + '\'\n';
							}
						}
					}
					/* REMOVE-BEGIN */
					// unset HWADDR for any/all non-primary VIFs we have configured
					//			s += 'nvram unset wl' + u + '_hwaddr\n';
					// AB TODO: figure out what to do with pre-existing/set MAC addresses
					//			if (vif >= 0) {
					//				if ((vifs_defined[vif][9] == '00:00:00:00:00:00') || (vifs_defined[vif][9] == '')) {
					//					s += 'nvram unset wl' + u + '_hwaddr\n';
					//				}
					//			}
					/* REMOVE-END */
				}
			}

			/* Clean-up deleted interfaces */
			var lan_ifnames = nvram['lan_ifnames'];
			var lan1_ifnames = nvram['lan1_ifnames'];
			var lan2_ifnames = nvram['lan2_ifnames'];
			var lan3_ifnames = nvram['lan3_ifnames'];
			var wl0_vifs = nvram['wl0_vifs'];
			var wl1_vifs = nvram['wl1_vifs'];

			for (var vidx = 0; vidx < vifs_deleted.length; ++vidx) {
				var u = vifs_deleted[vidx];
				for (var i = 0; i < elem.length ; ++i) {
					if (elem[i].name.indexOf('wl' + u) == 0) {
						s += 'nvram unset ' + elem[i].name + '\n';
					}
				}
				lan_ifnames = lan_ifnames.replace('wl'+u, '');
				lan1_ifnames = lan1_ifnames.replace('wl'+u, '');
				lan2_ifnames = lan2_ifnames.replace('wl'+u, '');
				lan3_ifnames = lan3_ifnames.replace('wl'+u, '');
				if (typeof(wl0_vifs) != 'undefined') {
					wl0_vifs = wl0_vifs.replace('wl'+u, '');
				}
				if (typeof(wl1_vifs) != 'undefined') {
					wl1_vifs = wl1_vifs.replace('wl'+u, '');
				}
				s += 'nvram unset wl' + u + '_wme\n';
				s += 'nvram unset wl' + u + '_bss_maxassoc\n';
			}
			if (vifs_deleted.length > 0)
			{
				s += 'nvram set lan_ifnames=\'' + lan_ifnames + '\'\n';
				s += 'nvram set lan1_ifnames=\'' + lan1_ifnames + '\'\n';
				s += 'nvram set lan2_ifnames=\'' + lan2_ifnames + '\'\n';
				s += 'nvram set lan3_ifnames=\'' + lan3_ifnames + '\'\n';
				if (typeof(wl0_vifs) != 'undefined')
					s += 'nvram set wl0_vifs=\'' + wl0_vifs + '\'\n';
				if (typeof(wl1_vifs) != 'undefined')
					s += 'nvram set wl1_vifs=\'' + wl1_vifs + '\'\n';
			}
			post_pre_submit_form(s);
		}

		function error_pre_submit_form() {
			var footermsg = E('footer-msg');

			footermsg.innerHTML = '<tt>' + escapeText(cmdresult) + '</tt>';
			footermsg.style.visibility = 'visible';

			cmdresult = '';
		}

		function post_pre_submit_form(s) {
			if (cmd) return;

			cmd = new XmlHttp();
			cmd.onCompleted = function(text, xml) {
				form.submit(E('_fom'),1);
			}
			cmd.onError = function(x) {
				cmdresult = '<% translate("ERROR"); %>: ' + x;
				error_pre_submit_form();
			}

			cmd.post('shell.cgi', 'action=execute&command=' + escapeCGI(s.replace(/\r/g, '')));
		}

		function escapeText(s) {
			function esc(c) {
				return '&#' + c.charCodeAt(0) + ';';
			}
			return s.replace(/[&"'<>]/g, esc).replace(/\n/g, ' <br>').replace(/ /g, '&nbsp;');
		}

	</script>

	<form id="_fom" method="post" action="tomato.cgi">
	<input type="hidden" name="_nextpage" value="/#advanced-wlanvifs.asp">
	<input type="hidden" name="_nextwait" value="10">
	<input type="hidden" name="_service" value="wireless-restart">
	<input type="hidden" name="_force_commit" value="1">

	<!-- LINUX24-BEGIN -->
	<input type="hidden" name="nas_alternate" value="">
	<!-- LINUX24-END -->
	<input type="hidden" name="lan_ifnames" value="">
	<input type="hidden" name="lan1_ifnames" value="">
	<input type="hidden" name="lan2_ifnames" value="">
	<input type="hidden" name="lan3_ifnames" value="">

	<div class="box" id="sesdiv" style="display:none">
		<div class="heading"><% translate("Virtual Wireless Interfaces"); %></div>

		<div class="content">

			<div id="tabsmain"></div><br />
			<script type="text/javascript">$('#tabsmain').append(tabCreate.apply(this, tabs));</script>

			<div id="overview-tab">
				<table class="line-table" id="wlif-grid"></table><br />

				<h3><a href="javascript:toggleVisibility('details');"><% translate("Wireless Interfaces Details"); %> <span id="sesdiv_details_showhide"><i class="icon-chevron-up"></i></span></a></h3>
				<div class="section fixtables" id="sesdiv_details" style="display:none">

					<script type="text/javascript">
						var c = [];
						for (var uidx = 0; uidx < wl_ifaces.length; ++uidx) {
							if (wl_sunit(uidx)<0) {
								c.push({ title: '<% translate("Interface"); %>', text: 'wl' + wl_fface(uidx) + ' <small>(' + wl_display_ifname(uidx) + ')</small>' });
								c.push({ title: '<% translate("Virtual Interfaces"); %>', indent: 2, rid: 'wl' + wl_fface(uidx) + '_vifs',
									text: 'wl' + wl_fface(uidx) + ' ' +  nvram['wl' + wl_fface(uidx) + '_vifs'] + ' <small>(max ' + wl_ifaces[uidx][7] + ')</small>' });

							}
						}

						createFieldTable('',c, '#sesdiv_details', 'line-table');
					</script>
				</div><br />

				<!-- LINUX24-BEGIN -->
				<h3><a href="javascript:toggleVisibility('options');"><% translate("Options"); %> <span id="sesdiv_options_showhide"><i class="icon-chevron-up"></i></span></a></h3>
				<div class="section" id="sesdiv_options" style="display:none"></div><hr>
				<script type="text/javascript">
					$('#sesdiv_options').forms([
						{ title: '<% translate("Use alternate NAS startup sequence"); %>', name: 'f_nas_alternate', type: 'checkbox', value: nvram.nas_alternate == '1' }
					]);
				</script>
				<!-- LINUX24-END -->

			</div>

			<div id="tabsetc"></div>

			<script type="text/javascript">
				var htmlOut = '';
				for (var i = 1; i < tabs.length; ++i) {
					var t = tabs[i][0];
					var uidx = wl_ifidxx(t);
					var u = t;

					htmlOut += ('<div id="'+t+'-tab-disabled">');
					htmlOut += ('<br />');
					htmlOut += ('&nbsp;&nbsp;<span class="text-red"><i class="icon-cancel"></i></span> <% translate("VIF"); %> <b>' + tabs[i][1] + '</b> <% translate("is not defined"); %>.</b><br /><br />');
					htmlOut += ('</div>');

					htmlOut += ('<div id="'+t+'-tab">');
					htmlOut += ('<br>');

					// common to all VIFs
					htmlOut += ('<input type="hidden" id="_wl'+u+'_radio"       name="wl'+u+'_radio"       >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_mode"        name="wl'+u+'_mode"        >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_closed"      name="wl'+u+'_closed"      >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_key"         name="wl'+u+'_key"         >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_akm"         name="wl'+u+'_akm"         >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_auth_mode"   name="wl'+u+'_auth_mode"   >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_wep"         name="wl'+u+'_wep"         >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_auth"        name="wl'+u+'_auth"        >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_bss_enabled" name="wl'+u+'_bss_enabled" >');
					htmlOut += ('<input type="hidden" id="_wl'+u+'_ifname"      name="wl'+u+'_ifname"      >');

					// only if primary VIF
					if (u.toString().indexOf('.') < 0) {
						htmlOut += ('<input type="hidden" id="_wl'+u+'_nband"      name="wl'+u+'_nband"      >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_wds_enable" name="wl'+u+'_wds_enable" >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_wds"        name="wl'+u+'_wds"        >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_lazywds"    name="wl'+u+'_lazywds"    >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_gmode"      name="wl'+u+'_gmode"      >');

						htmlOut += ('<input type="hidden" id="_wl'+u+'_nmode"      name="wl'+u+'_nmode"      >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_nmcsidx"    name="wl'+u+'_nmcsidx"    >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_nreqd"      name="wl'+u+'_nreqd"      >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_nctrlsb"    name="wl'+u+'_nctrlsb"    >');
						htmlOut += ('<input type="hidden" id="_wl'+u+'_nbw"        name="wl'+u+'_nbw"        >');

						htmlOut += ('<input type="hidden" id="_wl'+u+'_vifs"       name="wl'+u+'_vifs"       >');
					}

					var f = [];
					f.push (
						{ title: '<% translate("Enable Interface"); %>', name: 'f_wl'+u+'_radio', type: 'checkbox',
							value: (eval('nvram["wl'+u+'_radio"]') == '1') && (eval('nvram["wl'+u+'_net_mode"]') != 'disabled') },
						{ title: '<% translate("MAC Address"); %>', text: '<a href="advanced-mac.asp">' + (eval('nvram["wl'+u+'_hwaddr"]') || '00:00:00:00:00:00') + '</a>' +
							' &nbsp; <b id="wl'+u+'_hwaddr_msg" style="visibility:hidden"><small>(<% translate("warning: WL driver reports BSSID"); %> <a class="ajaxload" href=advanced-mac.asp>' + ((typeof(wl_ifaces[wl_ifidxx(u)]) != 'undefined')? wl_ifaces[wl_ifidxx(u)][9] : '') + '</a>)</small></b>' },
						{ title: '<% translate("Wireless Mode"); %>', name: 'f_wl'+u+'_mode', type: 'select',
							options: wl_modes_available,
							value: ((eval('nvram["wl'+u+'_mode"]') == 'ap') && (eval('nvram["wl'+u+'_wds_enable"]') == '1')) ? 'apwds' : eval('nvram["wl'+u+'_mode"]'),
							suffix: ' &nbsp; <b id="wl'+u+'_mode_msg" style="visibility:hidden"><small>(<% translate("note: you might wish to cross-check settings later on"); %> <a class="ajaxload" href=basic-network.asp><% translate("Basic Settings"); %></a>)</small></b>' }
					);

					// only if primary VIF
					if (u.toString().indexOf('.') < 0) {
						f.push (
							{ title: '<% translate("Radio Band"); %>', name: 'f_wl'+u+'_nband', type: 'select', options: bands[uidx],
								value: eval('nvram["wl'+u+'_nband"]') || '0' == '0' ? bands[uidx][0][0] : eval('nvram["wl'+u+'_nband"]') },
							{ title: '<% translate("Wireless Network Mode"); %>', name: 'wl'+u+'_net_mode', type: 'select',
								value: (eval('nvram["wl'+u+'_net_mode"]') == 'disabled') ? 'mixed' : eval('nvram["wl'+u+'_net_mode"]'),
								options: [], prefix: '<span id="__wl'+u+'_net_mode">', suffix: '</span>' }
						);
					}

					if (typeof(eval('nvram["wl'+u+'_closed"]')) == 'undefined')
						nvram['wl'+u+'_closed'] = '0';

					f.push (
						{ title: '<% translate("SSID"); %>', name: 'wl'+u+'_ssid', type: 'text', maxlen: 32, size: 34, value: eval('nvram["wl'+u+'_ssid"]') },
						{ title: '<% translate("Broadcast"); %>', indent: 2, name: 'f_wl'+u+'_bcast', type: 'checkbox', value: (eval('nvram["wl'+u+'_closed"]') == '0') }
					);

					// only if primary VIF
					if (u.toString().indexOf('.') < 0) {
						f.push (
							{ title: '<% translate("Channel"); %>', name: 'wl'+u+'_channel', type: 'select', options: ghz[uidx], prefix: '<span id="__wl'+u+'_channel">', suffix: '</span> <input type="button" id="_f_wl'+u+'_scan" value="<% translate("Scan"); %>" onclick="scanButton('+u+')"> <img src="spin.gif" id="spin'+u+'">',
								value: eval('nvram["wl'+u+'_channel"]') },
							{ title: '<% translate("Channel Width"); %>', name: 'wl'+u+'_nbw_cap', type: 'select', options: [['0','20 MHz'],['1','40 MHz']],
								value: eval('nvram["wl'+u+'_nbw_cap"]') },
							{ title: '<% translate("Control Sideband"); %>', name: 'f_wl'+u+'_nctrlsb', type: 'select', options: [['lower','<% translate("Lower"); %>'],['upper','<% translate("Upper"); %>']],
								value: eval('nvram["wl'+u+'_nctrlsb"]') == 'none' ? 'lower' : eval('nvram["wl'+u+'_nctrlsb"]') }
						);
					}

					if (typeof(eval('nvram["wl'+u+'_crypto"]')) == 'undefined')
						nvram['wl'+u+'_crypto'] = 'aes';

					f.push (
						null,
						{ title: '<% translate("Security"); %>', name: 'wl'+u+'_security_mode', type: 'select',
							options: [['disabled','<% translate("Disabled"); %>'],['wep','<% translate("WEP"); %>'],['wpa_personal','<% translate("WPA Personal"); %>'],['wpa_enterprise','<% translate("WPA Enterprise"); %>'],['wpa2_personal','<% translate("WPA2 Personal"); %>'],['wpa2_enterprise','<% translate("WPA2 Enterprise"); %>'],['wpaX_personal','<% translate("WPA / WPA2 Personal"); %>'],['wpaX_enterprise','<% translate("WPA / WPA2 Enterprise"); %>'],['radius','<% translate("Radius"); %>']],
							value: eval('nvram["wl'+u+'_security_mode"]') },
						{ title: '<% translate("Encryption"); %>', indent: 2, name: 'wl'+u+'_crypto', type: 'select',
							options: [['tkip','<% translate("TKIP"); %>'],['aes','<% translate("AES"); %>'],['tkip+aes','<% translate("TKIP / AES"); %>']], value: eval('nvram["wl'+u+'_crypto"]') },
						{ title: '<% translate("Shared Key"); %>', indent: 2, name: 'wl'+u+'_wpa_psk', type: 'password', maxlen: 64, size: 64, peekaboo: 1,
							suffix: ' <button class="btn" type="button" id="_f_wl'+u+'_psk_random1" value="<% translate("Random"); %>" onclick="random_psk(\'_wl'+u+'_wpa_psk\')"><% translate("Random"); %></button>',
							value: eval('nvram["wl'+u+'_wpa_psk"]') },
						{ title: '<% translate("Shared Key"); %>', indent: 2, name: 'wl'+u+'_radius_key', type: 'password', maxlen: 80, size: 32, peekaboo: 1,
							suffix: ' <button class="btn" type="button" id="_f_wl'+u+'_psk_random2" value="<% translate("Random"); %>" onclick="random_psk(\'_wl'+u+'_radius_key\')"><% translate("Random"); %></button>',
							value: eval('nvram["wl'+u+'_radius_key"]') },
						{ title: '<% translate("Group Key Renewal"); %>', indent: 2, name: 'wl'+u+'_wpa_gtk_rekey', type: 'text', maxlen: 4, size: 6, suffix: ' <% translate("seconds"); %>',
							value: eval('nvram["wl'+u+'_wpa_gtk_rekey"]') || '3600' },
						{ title: '<% translate("Radius Server"); %>', indent: 2, multi: [
							{ name: 'wl'+u+'_radius_ipaddr', type: 'text', maxlen: 15, size: 17, value: eval('nvram["wl'+u+'_radius_ipaddr"]') },
							{ name: 'wl'+u+'_radius_port', type: 'text', maxlen: 5, size: 7, prefix: ' : ', value: eval('nvram["wl'+u+'_radius_port"]') || '1812' } ] },
						{ title: '<% translate("Encryption"); %>', indent: 2, name: 'wl'+u+'_wep_bit', type: 'select', options: [['128','128-bits'],['64','64-bits']],
							value: eval('nvram["wl'+u+'_wep_bit"]') },
						{ title: '<% translate("Passphrase"); %>', indent: 2, name: 'wl'+u+'_passphrase', type: 'text', maxlen: 16, size: 20,
							suffix: ' <input type="button" id="_f_wl'+u+'_wep_gen" value="<% translate("Generate"); %>" onclick="generate_wep('+u+')"> <button class="btn" type="button" id="_f_wl'+u+'_wep_random" value="<% translate("Random"); %>" onclick="random_wep('+u+')"><% translate("Random"); %></button>',
							value: eval('nvram["wl'+u+'_passphrase"]') }
					);

					if (typeof(eval('nvram["wl'+u+'_key"]')) == 'undefined')
						nvram['wl'+u+'_key'] = '1';
					/* REMOVE-BEGIN */
					//		eval('nvram["wl'+u+'_key"] = 1');
					/* REMOVE-END */

					for (var j = 1; j <= 4; ++j) {
						f.push(
							{ title: ('Key ' + j), indent: 2, name: ('wl'+u+'_key' + j), type: 'text', maxlen: 26, size: 34,
								suffix: '<input type="radio" onchange="verifyFields(this,1)" onclick="verifyFields(this,1)" name="f_wl'+u+'_wepidx" id="_f_wl'+u+'_wepidx_' + j + '" value="' + j + '"' + ((eval('nvram["wl'+u+'_key"]') == j) ? ' checked>' : '>'),
								value: nvram['wl'+u+'_key' + j] });
					}

					f.push(null,
						{ title: '<% translate("WDS"); %>', name: 'f_wl'+u+'_lazywds', type: 'select',
							options: [['0','<% translate("Link With"); %>...'],['1','<% translate("Automatic"); %>']], value: nvram['wl'+u+'_lazywds'] } );
					/* REMOVE-BEGIN */
					//	alert('nvram["wl'+u+'_wds"]=' + eval('nvram["wl'+u+'_wds"]'));
					/* REMOVE-END */
					wds = eval('nvram["wl'+u+'_wds"]');
					if (typeof(wds) == 'undefined') {
						nvram['wl'+u+'_wds'] = '';
					}

					wds = eval('nvram["wl'+u+'_wds"]').split(/\s+/);
					/* REMOVE-BEGIN */
					//	wds = (nvram['wl'+u+'_wds']).split(/\s+/);
					/* REMOVE-END */
					for (var k = 0; k < 10; k += 2)	{
						f.push({ title: (k ? '' : '<% translate("MAC Address"); %>'), indent: 2, multi: [
							{ name: 'f_wl'+u+'_wds_' + k, type: 'text', maxlen: 17, size: 20, value: wds[k] || '00:00:00:00:00:00' },
							{ name: 'f_wl'+u+'_wds_' + (k + 1), type: 'text', maxlen: 17, size: 20, value: wds[k + 1] || '00:00:00:00:00:00' } ] } );
					}

					htmlOut += createFormFields(f);
					htmlOut += ('</div>');

				}

				$('#tabsetc').append(htmlOut);
			</script>
			<!-- / WLIFDIV / -->
		</div>
		<!-- / SESDIV / -->
	</div>

	<!-- NOTES -->
	<div class="box">
		<div class="heading"><% translate("Notes"); %> <a class="pull-right" data-toggle="tooltip" title="<% translate("Hide/Show Notes"); %>" href="javascript:toggleVisibility('notes');"><span id="sesdiv_notes_showhide"><i class="icon-chevron-up"></i></span></a></div>
		<div class="section content" id="sesdiv_notes" style="display:none">

			<ul>
				<li><b><% translate("Interface"); %></b> - <% translate("Wireless VIF name"); %>.</li>
				<li><b><% translate("Enabled"); %></b> - <% translate("If this VIF should be active and brought online"); %>.</li>
				<li><b><% translate("SSID"); %></b> - <% translate("Wireless Service Set Identifier"); %>.</li>
				<li><b><% translate("Mode"); %></b> - <% translate("Interface mode: Access Point, WDS, Wireless Client, etc"); %>...</li>
				<li><b><% translate("Bridge"); %></b> - <% translate("Which LAN bridge this VIF should be assigned"); %>.</li>
			</ul>

			<ul>
				<!-- LINUX24-BEGIN -->
				<li><b><% translate("Use alternate NAS startup"); %>(...)</b> - <i><% translate("Only meaningful for K24 builds"); %></i> - <% translate("Enable this option if you need more than one NAS process running (i.e. to handle WPAx encryption on more than one WLVIF)"); %>.</li>
				<!-- LINUX24-END -->
			</ul>

			<ul>
				<li><b><% translate("Other relevant notes/hints"); %>:</b>
				<ul>
					<li><% translate("When creating/defining a new wireless VIF, it's MAC address will be shown (incorrectly) as '00:00:00:00:00:00', as it's unknown at that moment (until network is restarted and this page is reloaded)"); %>.</li>
					<li><% translate("When saving changes, the MAC addresses of all defined non-primary wireless VIFs could sometimes be (already) <i>set</i> but might be <i>recreated</i> by the WL driver (so that previously defined/saved settings might need to be updated/changed accordingly on"); %> <a class="ajaxload" href=advanced-mac.asp><% translate("Advanced Settings"); %>/<% translate("MAC Address"); %></a> <% translate("after saving settings and rebooting your router"); %>).</li>
					<li><% translate("This web interface allows configuring a maximum of 4 VIFs for each physical wireless interface available - up to 3 extra VIFs can be defined in addition to the primary VIF (<i>on devices with multiple VIF capabilities</i>)"); %>.</li>
					<li><% translate("By definition, configuration settings for the <i>primary VIF</i> of any physical wireless interfaces shouldn't be touched here (use the"); %> <a class="ajaxload" href="basic-network.asp"><% translate("Basic Settings"); %>/<% translate("Network"); %></a> <% translate("page instead)"); %>.</li>
				</ul>
			</ul>

		</div>
	</div>


	<button type="button" value="<% translate("Save"); %>" id="save-button" onclick="save()" class="btn btn-primary"><% translate("Save"); %> <i class="icon-check"></i></button>
	<button type="button" value="<% translate("Cancel"); %>" id="cancel-button" onclick="javascript:reloadPage();" class="btn"><% translate("Cancel"); %> <i class="icon-cancel"></i></button>
	<span id="footer-msg" class="alert alert-warning" style="visibility: hidden;"></span>

	<script type="text/javascript">
		init();
		for (var uidx = 0; uidx < wl_ifaces.length; ++uidx) {
			if (wl_sunit(uidx) < 0) {
				refreshNetModes(uidx);
				refreshChannels(uidx);
			}
		}
		verifyFields(null, 1);
	</script>
</content>