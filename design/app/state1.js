
class Component extends DCLogic {
  state = { db: this.load(), tab: 'groups', page: null, pageArg: null, sheet: null, draft: {}, expanded: {}, venueSel: null, drag: null, toast: null, toastUndo: null, prevKids: null };
  load() {
    try { const d = JSON.parse(localStorage.getItem('sycamore_app_v1')); if (d && d.camps) return d; } catch (e) {}
    return { camps: [], activeCampId: null };
  }
  save() { localStorage.setItem('sycamore_app_v1', JSON.stringify(this.state.db)); }
  set(fn) { this.setState(fn, () => this.save()); }
  camp() { return this.state.db.camps.find(c => c.id === this.state.db.activeCampId) || null; }
  uid() { return Math.random().toString(36).slice(2, 9); }
  showToast(msg, undoable) {
    clearTimeout(this._tt);
    this.setState({ toast: msg, toastUndo: !!undoable });
    this._tt = setTimeout(() => this.setState({ toast: null, toastUndo: null }), 3200);
  }
  renderVals() {
    return Object.assign({}, this.authVals(), this.navVals(), this.campVals(), this.groupVals(), this.tournVals2(), this.sheetVals());
  }
  navVals() {
    const camp = this.camp(), st = this.state;
    const signedIn = !!st.db.signedIn;
    const showCamps = signedIn && (!camp || st.page === 'camps');
    const soonMap = {
      overview: ['Overview', 'What is on right now', 'The Now card, the needs-you strip and every court at a glance land here once days have a shape.'],
      schedule: ['Schedule', 'The day as blocks', 'Build each day from blocks, drag to resize, take attendance from any block.']
    };
    const soon = soonMap[st.tab];
    const mk = (id, icon, label) => ({
      icon: (st.tab === id ? 'ph-fill ph-' : 'ph ph-') + icon,
      label, active: st.tab === id,
      bg: st.tab === id ? '#F3F5F4' : 'transparent',
      pad: st.tab === id ? '11px 15px' : '11px 13px',
      color: st.tab === id ? '#1A7F55' : '#8A8E96',
      go: () => this.setState({ tab: id, page: null, pageArg: null, sheet: null })
    });
    return {
      showCamps,
      showApp: signedIn && !!camp && st.page !== 'camps',
      tabIsGroups: st.tab === 'groups' && !st.page,
      closePage: () => this.setState(s => ({ page: s.page === 'shape' ? 'camp' : null, pageArg: null })),
      openProfile: () => this.setState({ page: 'camp' }),
      campName: camp ? camp.name : '',
      tabIsSoon: !st.page && !!soon,
      soonTitle: soon ? soon[0] : '', soonHead: soon ? soon[1] : '', soonBody: soon ? soon[2] : '',
      goGroups: () => this.setState({ tab: 'groups', page: null }),
      tabs: [mk('overview', 'squares-four', 'Overview'), mk('schedule', 'calendar-blank', 'Schedule'), mk('groups', 'list-numbers', 'Groups'), mk('tourn', 'trophy', 'Tournament')],
      toast: st.toast, toastUndo: st.toastUndo,
      undo: () => { if (st.prevKids) this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.kids = s.prevKids; return { db: s.db, prevKids: null, toast: null, toastUndo: null }; }); }
    };
  }
  campVals() {
    const st = this.state;
    return Object.assign(this.campTabVals(), {
      campCards: st.db.camps.map(c => ({
        initial: (c.name || '?').slice(0, 1).toUpperCase(), name: c.name, role: c.role || 'Admin',
        sub: c.kids.length ? c.kids.length + ' kids · ' + c.venues.map(v => v.name).join(' + ') : (c.venues.length ? c.venues.map(v => v.name).join(' + ') : 'Not shaped yet'),
        open: () => this.set(s => { s.db.activeCampId = c.id; return { db: s.db, page: c.venues.length ? null : 'camp', tab: 'groups' }; })
      })),
      noCamps: st.db.camps.length === 0,
      openNewCamp: () => this.setState({ sheet: 'newCamp', draft: { name: '' } }),
      openJoin: () => this.setState({ sheet: 'join', draft: { code: '' } })
    });
  }
  groupVals() {
    const st = this.state, camp = this.camp();
    if (!camp) return {};
    const venues = camp.venues;
    const venue = venues.find(v => v.id === st.venueSel) || venues[0] || null;
    const vals = {
      hasVenues: venues.length > 0,
      noVenueYet: venues.length === 0,
      venueName: venue ? venue.name : '',
      manyVenues: venues.length > 1,
      venueNext: () => { if (venues.length < 2 || !venue) return; const i = venues.indexOf(venue); this.setState({ venueSel: venues[(i + 1) % venues.length].id, expanded: {} }); },
      importSample: () => this.importSample()
    };
    if (!venue) return Object.assign(vals, { noKidsYet: false, uneven: false, groupCards: [], dragGhost: false });
    const groups = this.kidsByGroup(camp, venue);
    const counts = groups.map(g => g.length);
    const total = counts.reduce((a, b) => a + b, 0);
    vals.groupsMeta = total + ' kids · ' + venue.groups + ' groups';
    vals.noKidsYet = total === 0;
    vals.groupCountWord = venue.groups + ' groups';
    vals.uneven = total > 0 && (Math.max.apply(null, counts) - Math.min.apply(null, counts)) > 1 && !(st.q || '').trim();
    vals.countsLine = counts.join(' · ');
    vals.openEvenOut = () => this.setState({ sheet: 'evenOut' });
    const q = (st.q || '').trim().toLowerCase();
    vals.gq = st.q || '';
    vals.setGq = (e) => this.setState({ q: e.target.value });
    vals.gqOn = !!q;
    vals.clearGq = () => this.setState({ q: '' });
    const altered = !!q;
    const drag = st.drag, FOLD = 6;
    const offs = []; let acc = 0; groups.forEach(l => { offs.push(acc); acc += l.length; });
    vals.groupCards = groups.map((list, gi) => {
      const expanded = !!st.expanded[gi];
      const filtered = q ? list.filter(k => k.name.toLowerCase().indexOf(q) >= 0) : list;
      const visible = altered ? filtered : ((expanded || list.length <= FOLD) ? list : list.slice(0, FOLD - 1));
      if (altered && !visible.length) return null;
      return {
        idx: gi,
        title: 'Group ' + (gi + 1),
        count: list.length + (list.length === 1 ? ' kid' : ' kids'),
        over: venue.target && list.length > venue.target ? (list.length - venue.target) + ' over' : null,
        bg: '#fff',
        border: drag && drag.moved && drag.overGroup === gi ? '1.5px solid #C3DFCF' : '1px solid #EDEEF1',
        tailLine: drag && drag.moved && drag.overGroup === gi && drag.dropIdx >= visible.length ? '2px solid #1A7F55' : '2px solid transparent',
        rows: visible.map((k, ri) => ({
          id: k.id, rank: offs[gi] + list.indexOf(k) + 1, name: k.name,
          dim: (drag && drag.kidId === k.id) ? .35 : (this.kidAwayOn(k, 'Today') ? .55 : 1),
          leaves: this.kidAwayOn(k, 'Today') ? false : ((this.getLeaves(k).find(x => x.day === 'Today') || {}).time || false), away: this.kidAwayOn(k, 'Today'),
          genderIcon: k.gender === 'F' ? 'ph ph-gender-female' : 'ph ph-gender-male',
          line: drag && drag.moved && drag.overGroup === gi && drag.dropIdx === ri ? '2px solid #1A7F55' : '2px solid transparent',
          open: () => { if (this._dragMoved) return; this.setState({ page: 'kid', pageArg: k.id }); },
          down: (e) => { if (!altered) this.startDrag(e, k, gi); }
        })),
        moreLabel: (!altered && list.length > FOLD) ? (expanded ? 'Show fewer' : '+' + (list.length - (FOLD - 1)) + ' more') : null,
        moreIcon: expanded ? 'ph ph-caret-up' : 'ph ph-caret-down',
        toggleMore: () => this.setState(s => ({ expanded: Object.assign({}, s.expanded, { [gi]: !expanded }) }))
      };
    }).filter(Boolean);
    const unassigned = camp.kids.filter(k => !k.venueId);
    vals.unassignedNote = (unassigned.length && !q) ? ('Unassigned · ' + unassigned.length + ' — search a name to add them to ' + (venue ? venue.name : 'a venue') + '.') : null;
    if (q) {
      const hits = unassigned.filter(k => k.name.toLowerCase().indexOf(q) >= 0);
      vals.hasUnassignedHits = hits.length > 0;
      vals.unassignedHits = hits.map(k => ({ name: k.name, meta: k.age + ' · ' + k.gender + ' · unassigned', add: () => this.assignKid(k.id, venue) }));
    }
    vals.gqEmpty = altered && total > 0 && vals.groupCards.length === 0 && !vals.hasUnassignedHits;
    vals.dragGhost = !!(drag && drag.moved);
    vals.ghostXY = drag ? 'translateY(' + Math.round(drag.y) + 'px)' : 'translateY(0)';
    vals.dragName = drag ? drag.name : '';
    const kid = camp.kids.find(k => k.id === st.pageArg);
    vals.pageKid = st.page === 'kid' && !!kid;
    if (vals.pageKid) {
      const kvenue = venues.find(v => v.id === kid.venueId);
      const klist = kvenue ? (this.kidsByGroup(camp, kvenue)[kid.group] || []) : [];
      vals.kidName = kid.name;
      vals.kidMeta = kid.age + ' · ' + kid.gender + (kvenue ? ' · ' + kvenue.name : '');
      vals.kidGroup = 'Group ' + (kid.group + 1);
      vals.kidRank = kid.rank + ' of ' + klist.length;
      vals.kidNotes = kid.notes || '';
      vals.setKidNotes = (e) => { const v = e.target.value; this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.kids.find(k => k.id === kid.id).notes = v; return { db: s.db }; }); };
      vals.openMove = () => this.setState({ sheet: 'move' });
      const leaves = this.getLeaves(kid);
      vals.leaveRows = leaves.map((lv, i) => ({
        time: lv.time, day: lv.day, line: i ? '1px solid #F2F3F6' : '0',
        edit: () => this.setState({ addingLeave: true, pendDay: lv.day, pendMins: this.parseLeaveTime(lv.time) }),
        remove: (e) => { if (e && e.stopPropagation) e.stopPropagation(); this.setKid(kid.id, k => { k.leavesList = this.getLeaves(k).filter((x, j) => j !== i); k.leaves = null; }); }
      }));
      vals.addingLeave = !!st.addingLeave;
      vals.notAddingLeave = !st.addingLeave;
      vals.addLeaveLine = leaves.length ? '1px solid #F2F3F6' : '0';
      vals.startAddLeave = () => this.setState({ addingLeave: true, pendDay: 'Today', pendMins: 870 });
      vals.cancelLeave = () => this.setState({ addingLeave: false });
      vals.dayPills = ['Today', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map(dy => ({ label: dy, bg: st.pendDay === dy ? '#0B0B0C' : '#F1F2F5', color: st.pendDay === dy ? '#fff' : '#5C6068', pick: () => this.setState({ pendDay: dy }) }));
      const pm = st.pendMins || 870;
      vals.pendTimeLabel = this.fmtLeaveTime(pm);
      vals.timeDown = () => this.setState({ pendMins: Math.max(720, pm - 15) });
      vals.timeUp = () => this.setState({ pendMins: Math.min(1080, pm + 15) });
      vals.pendingLabel = (st.pendDay || 'Today') + ' ' + this.fmtLeaveTime(pm);
      vals.confirmLeave = () => {
        const dY = st.pendDay || 'Today', tM = this.fmtLeaveTime(pm);
        this.setKid(kid.id, k => { const cur = this.getLeaves(k); k.leavesList = cur.some(x => x.day === dY) ? cur.map(x => x.day === dY ? { day: dY, time: tM } : x) : cur.concat({ day: dY, time: tM }); k.leaves = null; });
        this.setState({ addingLeave: false });
        this.showToast('Leaves ' + tM + (dY === 'Today' ? ' today' : ' on ' + dY));
      };
      const awDays = kid.awayDays || (kid.away ? ['Today'] : []);
      vals.awaySub = awDays.length ? ('Out ' + awDays.join(', ') + ' — plans adapt') : 'Mark the days out — tournaments plan around it';
      vals.awayChips = ['Today', 'Day 2', 'Day 3', 'Day 4', 'Day 5'].map(lb => { const on = awDays.includes(lb); return { label: lb, bg: on ? '#0B0B0C' : '#F1F2F5', color: on ? '#fff' : '#5C6068', border: on ? '1.5px solid #0B0B0C' : '1.5px solid #E4E5E9', pick: () => this.setKid(kid.id, k => { const cur = k.awayDays || (k.away ? ['Today'] : []); k.awayDays = on ? cur.filter(x => x !== lb) : cur.concat(lb); k.away = k.awayDays.includes('Today'); }) }; });
      vals.removeLabel = st.confirmKid ? 'Tap again to remove ' + kid.name.split(' ')[0] : 'Remove from camp';
      vals.removeKid = () => {
        if (!this.state.confirmKid) { this.setState({ confirmKid: true }); setTimeout(() => this.setState({ confirmKid: false }), 2600); return; }
        const snap = JSON.parse(JSON.stringify(camp.kids));
        this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.kids = c.kids.filter(k => k.id !== kid.id); this.reindex(c); return { db: s.db, page: null, pageArg: null, confirmKid: false, prevKids: snap }; });
        this.showToast(kid.name + ' removed', true);
      };
    }
    return vals;
  }
  sheetVals() {
    const st = this.state, camp = this.camp(), d = st.draft || {};
    const vals = {
      anySheet: !!st.sheet,
      closeSheet: () => this.setState({ sheet: null, draft: {} }),
      dName: d.name || '', setDName: (e) => this.setDraft('name', e.target.value),
      dSubtitle: d.subtitle || '', setDSubtitle: (e) => this.setDraft('subtitle', e.target.value),
      dCode: d.code || '', setDCode: (e) => this.setDraft('code', e.target.value.toUpperCase()),
      ctaOpacity: 1, sheetContext: '', sheetTitle: ''
    };
    if (!st.sheet) return vals;
    const name = (d.name || '').trim();
    if (st.sheet === 'newCamp') {
      Object.assign(vals, {
        shNewCamp: true, sheetContext: 'Your camps', sheetTitle: 'New camp',
        ctaOpacity: name ? 1 : .45,
        createLabel: name ? 'Create ' + name : 'Create camp',
        createCamp: () => {
          if (!name) return;
          const id = this.uid();
          this.set(s => { s.db.camps.push({ id, name, code: 'SYC-' + Math.floor(1000 + Math.random() * 9000), role: 'Admin', season: '', venues: [], kids: [] }); s.db.activeCampId = id; return { db: s.db, tab: 'groups', page: 'shape', sheet: 'venue', draft: { name: '', subtitle: '', courts: 4, groups: 3, target: 0, coaches: [], coachInput: '', ageGroup: 'all' } }; });
        }
      });
    }
    if (st.sheet === 'join') {
      Object.assign(vals, {
        shJoin: true, sheetContext: 'Your camps', sheetTitle: 'Join with a code',
        joinFlag: d.flag || null, ctaOpacity: (d.code || '').trim() ? 1 : .45,
        joinCamp: () => {
          const code = (d.code || '').trim();
          if (!code) return;
          const hit = st.db.camps.find(c => c.code === code);
          if (hit) {
            this.set(s => {
              const h = s.db.camps.find(c => c.id === hit.id);
              h.staff = h.staff || [];
              const me = (s.db.email || 'you').split('@')[0];
              const nm = me.charAt(0).toUpperCase() + me.slice(1);
              if (!h.staff.includes(nm)) h.staff.push(nm);
              s.db.activeCampId = hit.id;
              return { db: s.db, sheet: null, draft: {}, page: null, tab: 'groups' };
            });
          }
          else this.setDraft('flag', 'No camp answers to that code. Check it with whoever runs the camp.');
        }
      });
    }
    if (st.sheet === 'venue' && camp) {
      const editing = !!d.venueId;
      const orig = editing ? camp.venues.find(v => v.id === d.venueId) : null;
      const venueKids = orig ? camp.kids.filter(k => k.venueId === orig.id).length : 0;
      Object.assign(vals, {
        shVenue: true, sheetContext: camp.name + ' · Shape the camp',
        sheetTitle: editing ? 'Edit ' + (orig ? orig.name : 'venue') : 'New venue',
        dCourts: d.courts, dGroups: d.groups,
        decCourts: () => this.setDraft('courts', Math.max(1, d.courts - 1)),
        incCourts: () => this.setDraft('courts', Math.min(40, d.courts + 1)),
        decGroups: () => this.setDraft('groups', Math.max(1, d.groups - 1)),
        incGroups: () => this.setDraft('groups', Math.min(12, d.groups + 1)),
        dTarget: d.target ? d.target : '—', dTargetColor: d.target ? '#0B0B0C' : '#A2A6AE',
        decTarget: () => this.setDraft('target', Math.max(0, (d.target || 0) - 1)),
        incTarget: () => this.setDraft('target', Math.min(40, (d.target || 0) + 1)),
        ageGroupChips: [['all', 'All ages'], ['under11', '11 & under'], ['up12', '12 & up']].map(p => { const on = (d.ageGroup || 'all') === p[0]; return { label: p[1], bg: on ? '#0B0B0C' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #0B0B0C' : '1.5px solid #E4E5E9', pick: () => this.setDraft('ageGroup', p[0]) }; }),
        dealLine: (editing && venueKids) ? (orig.groups !== d.groups ? 'Save re-deals all ' + venueKids + ' kids into ' + d.groups + ' groups by ladder order.' : orig.name + ' holds ' + venueKids + ' kids — moves happen in Groups.') : 'Import deals every fitting kid into these ' + d.groups + ' groups — kids outside the ages stay unassigned.',
        dealLineColor: (editing && venueKids && orig.groups !== d.groups) ? '#B67A16' : '#A2A6AE',
        hasStaff: (camp.staff || []).length > 0,
        noStaff: (camp.staff || []).length === 0,
        inviteCodeSheet: camp.code,
        staffPicks: (camp.staff || []).map(n => { const on = (d.coaches || []).includes(n); return { name: n, bg: on ? '#1A7F55' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #1A7F55' : '1.5px solid #E4E5E9', pick: () => this.setDraft('coaches', on ? (d.coaches || []).filter(x => x !== n) : (d.coaches || []).concat(n)) }; }),
        ctaOpacity: name ? 1 : .45,
        venueCta: editing ? 'Save changes' : (name ? 'Add ' + name : 'Add venue'),
        dEditing: editing,
        removeVenueLabel: d.confirmRemove ? ('Tap again — removes ' + (venueKids ? 'its ' + venueKids + ' kids too' : 'it for good')) : 'Remove this venue',
        removeVenue: () => {
          if (!d.confirmRemove) { this.setDraft('confirmRemove', true); return; }
          this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.venues = c.venues.filter(v => v.id !== d.venueId); c.kids = c.kids.filter(k => k.venueId !== d.venueId); return { db: s.db, sheet: null, draft: {}, venueSel: null }; });
          this.showToast((orig ? orig.name : 'Venue') + ' removed');
        },
        saveVenue: () => {
          if (!name) return;
          this.set(s => {
            const c = s.db.camps.find(x => x.id === s.db.activeCampId);
            if (editing) {
              const v = c.venues.find(x => x.id === d.venueId);
              v.name = name; v.subtitle = (d.subtitle || '').trim(); v.courts = d.courts; v.target = d.target || 0; v.coaches = (d.coaches || []).slice(); v.ageGroup = d.ageGroup || 'all';
              if (v.groups !== d.groups) { v.groups = d.groups; this.redeal(c, v); }
              return { db: s.db, sheet: null, draft: {} };
            }
            const id = this.uid();
            c.venues.push({ id, name, subtitle: (d.subtitle || '').trim(), courts: d.courts, groups: d.groups, target: d.target || 0, coaches: (d.coaches || []).slice(), ageGroup: d.ageGroup || 'all' });
            return { db: s.db, sheet: null, draft: {}, venueSel: id };
          });
          if (!editing) this.showToast(name + ' added');
        }
      });
    }
    if (st.sheet === 'evenOut' && camp) {
      const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0];
      const ep = this.evenPlan(camp, venue);
      Object.assign(vals, {
        shEvenOut: true,
        sheetContext: venue.name + ' · ' + ep.plan.map(p => p.from).join(' · '),
        sheetTitle: 'Even out the groups?',
        evenRows: ep.plan.map((p, i) => ({ title: 'Group ' + (i + 1), from: p.from, to: p.to, line: i ? '1px solid #F2F3F6' : '0' })),
        evenMoves: ep.moves === 1 ? '1 kid moves.' : ep.moves + ' kids move.',
        evenCta: 'Even out · ' + ep.moves + (ep.moves === 1 ? ' move' : ' moves'),
        applyEvenOut: () => {
          const snap = JSON.parse(JSON.stringify(camp.kids));
          this.set(s => {
            const c = s.db.camps.find(x => x.id === s.db.activeCampId);
            this.redeal(c, c.venues.find(v => v.id === venue.id));
            return { db: s.db, sheet: null, prevKids: snap };
          });
          this.showToast('Groups evened out · ' + ep.moves + ' moved', true);
        }
      });
    }
    if (st.sheet === 'move' && camp) {
      const kid = camp.kids.find(k => k.id === st.pageArg);
      if (kid) {
        const kvenue = camp.venues.find(v => v.id === kid.venueId);
        const lists = this.kidsByGroup(camp, kvenue);
        Object.assign(vals, {
          shMove: true, sheetContext: kid.name + ' · ' + kvenue.name,
          sheetTitle: 'Where does ' + kid.name.split(' ')[0] + ' go?',
          moveRows: lists.map((l, i) => ({
            title: 'Group ' + (i + 1),
            sub: l.length + (l.length === 1 ? ' kid' : ' kids'),
            line: i ? '1px solid #F2F3F6' : '0',
            current: kid.group === i, notCurrent: kid.group !== i, dim: 1,
            pick: () => {
              if (kid.group === i) { this.setState({ sheet: null }); return; }
              const snap = JSON.parse(JSON.stringify(camp.kids));
              this.applyMove(kid.id, i, 999);
              this.setState({ sheet: null, prevKids: snap });
              this.showToast(kid.name.split(' ')[0] + ' → Group ' + (i + 1), true);
            }
          }))
        });
      }
    }
    if (st.sheet === 'import' && camp) {
      const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0];
      const rows = this.parseRoster(d.paste || '');
      Object.assign(vals, {
        shImport: true,
        sheetContext: camp.name + (venue ? ' · ' + venue.name : ''),
        sheetTitle: 'Bring in the kids',
        dPaste: d.paste || '', setDPaste: (e) => this.setDraft('paste', e.target.value),
        fileChosen: (e) => {
          const f = e.target.files && e.target.files[0]; if (!f) return;
          const r = new FileReader();
          r.onload = () => { const parsed = this.parseRoster(String(r.result)); if (parsed.length) this.doImport(parsed); else this.showToast('Nothing readable in that file'); };
          r.readAsText(f);
        },
        importHint: venue ? 'Deals every kid into ' + venue.name + '\u2019s ' + venue.groups + ' groups, evenly — rank them after.' : '',
        pasteCta: rows.length ? 'Add ' + rows.length + (rows.length === 1 ? ' kid' : ' kids') : 'Add kids',
        pasteOp: rows.length ? 1 : .45,
        addPasted: () => { if (rows.length) this.doImport(rows); },
        useSample: () => { this.setState({ sheet: null, draft: {} }); this.importSample(); }
      });
    }
    if (st.sheet === 'tourney' && camp) {
      const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0];
      const groupsSel = d.tGroups || [0];
      const pool = venue ? this.ladderOf(camp, venue).filter(k => groupsSel.indexOf(k.group) >= 0) : [];
      const kindD = d.kind || 'singles';
      Object.assign(vals, {
        shTourney: true,
        sheetContext: (venue ? venue.name : '') + ' · ' + pool.length + ' kids in',
        sheetTitle: 'New tournament',
        kindPills: [['singles', 'Singles'], ['doubles', 'Doubles'], ['team', 'Team tennis']].map(p => { const on = kindD === p[0]; return { label: p[1], bg: on ? '#0B0B0C' : '#F1F2F5', color: on ? '#fff' : '#5C6068', pick: () => this.setDraft('kind', p[0]) }; }),
        groupChips: Array.from({ length: venue ? venue.groups : 0 }, (_, gi) => { const on = groupsSel.indexOf(gi) >= 0; const cnt = this.kidsByGroup(camp, venue)[gi].length; return { label: 'Group ' + (gi + 1) + ' · ' + cnt, bg: on ? '#0B0B0C' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #0B0B0C' : '1.5px solid #E4E5E9', pick: () => this.setDraft('tGroups', on ? groupsSel.filter(x => x !== gi) : groupsSel.concat(gi)) }; }),
        tourIsTeam: kindD === 'team', tourNotTeam: kindD !== 'team',
        modePills: [['rr', 'Round robin'], ['draw', 'Draw']].map(p => { const on = (d.mode || 'rr') === p[0]; return { label: p[1], bg: on ? '#0B0B0C' : '#F1F2F5', color: on ? '#fff' : '#5C6068', pick: () => this.setDraft('mode', p[0]) }; }),
        dDays: d.days || 2,
        daysDec: () => this.setDraft('days', Math.max(1, (d.days || 2) - 1)),
        daysInc: () => this.setDraft('days', Math.min(5, (d.days || 2) + 1)),
        dTeams: d.teams || 2,
        teamsDec: () => this.setDraft('teams', Math.max(2, (d.teams || 2) - 1)),
        teamsInc: () => this.setDraft('teams', Math.min(8, (d.teams || 2) + 1)),
        tourHint: kindD === 'team' ? 'Snake draft by rank — every team gets a full spread. Coaches assigned on the team card.' : ((d.mode || 'rr') === 'rr' ? 'Everyone plays everyone. ' : 'Seeded bracket, byes to top ranks. ') + 'The order of play front-loads early leavers and plans around away days.',
        tourIsDoubles: kindD === 'doubles',
        createTourneyCta: pool.length ? ('Create · ' + pool.length + ' kids') : 'Pick at least one group',
        tourCtaOp: pool.length ? 1 : .45,
        doCreateTourney: () => { if (pool.length) this.createTourney2(); }
      });
      if (kindD === 'doubles') {
        const req = d.reqPairs || [];
        const paired = {}; req.forEach(p => { paired[p[0]] = true; paired[p[1]] = true; });
        const kmap2 = {}; camp.kids.forEach(k => { kmap2[k.id] = k; });
        Object.assign(vals, {
          hasReqPairs2: req.length > 0,
          reqPairChips2: req.map((p, i) => ({ label: this.shortName(kmap2[p[0]]) + ' + ' + this.shortName(kmap2[p[1]]), remove: () => this.setDraft('reqPairs', req.filter((x, j) => j !== i)) })),
          pairHint2: d.pendA ? 'Now tap ' + this.shortName(kmap2[d.pendA]) + '\u2019s partner.' : 'Tap two kids to pair them — the rest pair by skill.',
          unpairedChips2: pool.filter(k => !paired[k.id]).map(k => { const on = d.pendA === k.id; return { label: this.shortName(k), bg: on ? '#0B0B0C' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #0B0B0C' : '1.5px solid #E4E5E9', pick: () => { const a = this.state.draft.pendA; if (!a) this.setDraft('pendA', k.id); else if (a === k.id) this.setDraft('pendA', null); else this.setState(s => ({ draft: Object.assign({}, s.draft, { reqPairs: (s.draft.reqPairs || []).concat([[a, k.id]]), pendA: null }) })); } }; })
        });
      }
    }
    if (st.sheet === 'score' && camp) {
      const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0];
      const listT = venue ? ((camp.tournaments || {})[venue.id] || []) : [];
      const t = Array.isArray(listT) ? listT.find(x => x.id === d.tid) : null;
      if (t) {
        const sa = d.sa || 0, sb = d.sb || 0;
        const lead = sa === sb ? null : (sa > sb ? d.aN : d.bN);
        Object.assign(vals, {
          shScore: true, sheetContext: t.name + ' · ' + (d.mid || '').toUpperCase(), sheetTitle: 'Who took it?',
          scAN: d.aN, scBN: d.bN, scA: sa, scB: sb,
          scABorder: sa > sb ? '1.5px solid #C3DFCF' : '1.5px solid #E4E5E9', scABg: sa > sb ? '#F6FAF7' : '#fff', scAColor: sa > sb ? '#14684A' : '#0B0B0C',
          scBBorder: sb > sa ? '1.5px solid #C3DFCF' : '1.5px solid #E4E5E9', scBBg: sb > sa ? '#F6FAF7' : '#fff', scBColor: sb > sa ? '#14684A' : '#0B0B0C',
          aDec: () => this.setDraft('sa', Math.max(0, sa - 1)), aInc: () => this.setDraft('sa', Math.min(12, sa + 1)),
          bDec: () => this.setDraft('sb', Math.max(0, sb - 1)), bInc: () => this.setDraft('sb', Math.min(12, sb + 1)),
          scoreCta: sa === sb ? 'Scores can\u2019t tie' : ('Save · ' + lead + ' takes it ' + Math.max(sa, sb) + '\u2013' + Math.min(sa, sb)),
          scoreOp: sa === sb ? .45 : 1,
          saveScore: () => { if (sa === sb) return; this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); const tt = c.tournaments[venue.id].find(x => x.id === d.tid); tt.scores = tt.scores || {}; tt.scores[d.mid] = [sa, sb]; return { db: s.db, sheet: null, draft: {} }; }); },
          hasScore: !!(t.scores || {})[d.mid],
          clearScore: () => this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); const tt = c.tournaments[venue.id].find(x => x.id === d.tid); delete tt.scores[d.mid]; return { db: s.db, sheet: null, draft: {} }; })
        });
      }
    }
    if (st.sheet === 'season' && camp) {
      Object.assign(vals, {
        shSeason: true, sheetContext: 'Camp', sheetTitle: 'Name & season',
        ctaOpacity: name ? 1 : .45,
        saveSeason: () => { if (!name) return; this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.name = name; c.season = (d.subtitle || '').trim(); return { db: s.db, sheet: null, draft: {} }; }); }
      });
    }
    return vals;
  }
  setDraft(k, v) { this.setState(s => { const nd = Object.assign({}, s.draft); nd[k] = v; return { draft: nd }; }); }
  addCoachFromDraft() {
    const d = this.state.draft, n = (d.coachInput || '').trim();
    if (!n) return;
    this.setState(s => { const nd = Object.assign({}, s.draft); nd.coaches = (nd.coaches || []).concat(n); nd.coachInput = ''; return { draft: nd }; });
  }
  kidsByGroup(camp, venue) {
    return Array.from({ length: venue.groups }, (_, i) => camp.kids.filter(k => k.venueId === venue.id && k.group === i).sort((a, b) => a.rank - b.rank));
  }
  reindex(camp) {
    camp.venues.forEach(v => { this.kidsByGroup(camp, v).forEach((l, gi) => l.forEach((k, ri) => { k.group = gi; k.rank = ri + 1; })); });
  }
  ladderOf(camp, venue) {
    return camp.kids.filter(k => k.venueId === venue.id).sort((a, b) => (a.group - b.group) || (a.rank - b.rank));
  }
  bandSizes(total, n) {
    const base = Math.floor(total / n), extra = total % n;
    return Array.from({ length: n }, (_, i) => base + (i < extra ? 1 : 0));
  }
  evenPlan(camp, venue) {
    const lists = this.kidsByGroup(camp, venue);
    const ladder = this.ladderOf(camp, venue);
    const sizes = this.bandSizes(ladder.length, venue.groups);
    let p = 0, moves = 0;
    const plan = sizes.map((sz, gi) => {
      const band = ladder.slice(p, p + sz); p += sz;
      band.forEach(k => { if (k.group !== gi) moves++; });
      return { from: (lists[gi] || []).length, to: sz };
    });
    return { plan, moves };
  }
  redeal(camp, venue) {
    const ladder = this.ladderOf(camp, venue);
    const sizes = this.bandSizes(ladder.length, venue.groups);
    let p = 0;
    sizes.forEach((sz, gi) => { ladder.slice(p, p + sz).forEach((k, ri) => { k.group = gi; k.rank = ri + 1; }); p += sz; });
  }
  applyMove(kidId, toGroup, dropIdx) {
    this.set(s => {
      const camp = s.db.camps.find(c => c.id === s.db.activeCampId);
      const kid = camp.kids.find(k => k.id === kidId);
      const venue = camp.venues.find(v => v.id === kid.venueId);
      const lists = this.kidsByGroup(camp, venue).map(l => l.filter(k => k.id !== kidId));
      const g = Math.max(0, Math.min(toGroup, lists.length - 1));
      const idx = (dropIdx == null || dropIdx > lists[g].length) ? lists[g].length : dropIdx;
      lists[g].splice(idx, 0, kid);
      lists.forEach((l, gi) => l.forEach((k, ri) => { k.group = gi; k.rank = ri + 1; }));
      return { db: s.db };
    });
  }
  startDrag(e, kid, gi) {
    e.preventDefault(); e.stopPropagation();
    const root = e.target.closest('[data-screen-label]');
    if (!root) return;
    const rect = root.getBoundingClientRect();
    const startY = e.clientY;
    const onMove = (ev) => {
      const y = ev.clientY - rect.top - 16;
      let overGroup = null, dropIdx = null;
      const el = document.elementFromPoint(ev.clientX, ev.clientY);
      if (el && el.closest) {
        const row = el.closest('[data-kid]'), tail = el.closest('[data-tail]'), card = el.closest('[data-group]');
        if (row) {
          overGroup = +row.getAttribute('data-group');
          dropIdx = Array.prototype.indexOf.call(row.parentElement.querySelectorAll('[data-kid]'), row);
        } else if (tail) { overGroup = +tail.getAttribute('data-tail'); dropIdx = 999; }
        else if (card) { overGroup = +card.getAttribute('data-group'); dropIdx = 999; }
      }
      if (!this._dragMoved && Math.abs(ev.clientY - startY) < 4) return;
      this._dragMoved = true;
      const scroller = root.querySelector('[data-groups-scroll]');
      if (scroller) {
        const sr = scroller.getBoundingClientRect();
        if (ev.clientY < sr.top + 56) scroller.scrollTop -= 9;
        else if (ev.clientY > sr.bottom - 72) scroller.scrollTop += 9;
      }
      this.setState({ drag: { kidId: kid.id, name: kid.name, y, moved: true, overGroup, dropIdx } });
    };
    const onUp = () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      const dg = this.state.drag;
      if (dg && dg.moved && dg.overGroup != null) this.applyMove(kid.id, dg.overGroup, dg.dropIdx);
      this.setState({ drag: null });
      setTimeout(() => { this._dragMoved = false; }, 150);
    };
    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    this.setState({ drag: { kidId: kid.id, name: kid.name, y: e.clientY - rect.top - 16, moved: false, overGroup: gi, dropIdx: null } });
  }
  importSample() {
    const camp = this.camp(); if (!camp) return;
    const venue = camp.venues.find(v => v.id === this.state.venueSel) || camp.venues[0];
    if (!venue) { this.setState({ page: 'shape' }); return; }
    const F = ['Serene','Liam','Jonah','Mia','Noah','Ana','Caleb','Priya','Theo','Ivy','Omar','Ruth','Austin','Lena','Eli','Sofia','Marcus','Nina','Oscar','Dalia','Felix','June','Hana','Reid','Tessa','Kai','Wren','Diego','Isla','Rohan','Maeve','Silas','Nora','Ezra','Lucia','Owen','Zadie','Cole','Amara','Levi','Petra','Milo'];
    const L = ['Chu','Prior','Reyes','Karim','Bell','Sosa','Ito','Nair','Marsh','Tran','Haddad','Diaz','Vale','Wolf','Navarro','Brandt','Lee','Patel','Finch','Moss','Iqbal','Park','Sato','Lowe','Bianchi','Okafor','Hale','Fuentes','Kerr','Mehta','Quinn','Boone','Lindt','Adler','Romero','Tate','Cruz','Nguyen','Osei','Stone','Novak','Ferris'];
    let di = 0;
    const kids = F.map((f, i) => {
      const age = 8 + (i * 5) % 7;
      const base = { id: this.uid(), name: f + ' ' + L[i], age, gender: i % 2 ? 'F' : 'M', notes: '' };
      if (this.ageFits(venue, age)) { base.venueId = venue.id; base.group = di % venue.groups; base.rank = Math.floor(di / venue.groups) + 1; di++; }
      else { base.venueId = null; base.group = null; base.rank = null; }
      return base;
    });
    this.set(s => {
      const c = s.db.camps.find(x => x.id === s.db.activeCampId);
      c.kids = c.kids.filter(k => k.venueId && k.venueId !== venue.id).concat(kids);
      return { db: s.db, page: null, pageArg: null, tab: 'groups', venueSel: venue.id };
    });
    this.showToast(di + ' dealt into ' + venue.groups + ' groups' + (kids.length - di ? ' · ' + (kids.length - di) + ' unassigned' : ''));
  }
  authVals() {
    const st = this.state, email = st.authEmail || '';
    return {
      showSignIn: !st.db.signedIn,
      authEmailStep: st.authStep !== 'code',
      authCodeStep: st.authStep === 'code',
      authEmail: email,
      setAuthEmail: (e) => this.setState({ authEmail: e.target.value }),
      emailCtaOp: email.includes('@') ? 1 : .45,
      sendCode: () => { if (email.includes('@')) this.setState({ authStep: 'code' }); },
      authCode: st.authCode || '',
      setAuthCode: (e) => this.setState({ authCode: e.target.value.replace(/[^0-9]/g, '').slice(0, 6) }),
      codeCtaOp: (st.authCode || '').length >= 4 ? 1 : .45,
      doSignIn: () => { if ((st.authCode || '').length < 4) return; this.set(s => { s.db.signedIn = true; s.db.email = email; return { db: s.db, authStep: null, authCode: '' }; }); },
      backToEmail: () => this.setState({ authStep: null })
    };
  }
  setKid(id, fn) {
    this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); const k = c.kids.find(y => y.id === id); if (k) fn(k); return { db: s.db }; });
  }
  getLeaves(kid) { return kid.leavesList || (kid.leaves ? [{ day: 'Today', time: kid.leaves }] : []); }
  parseLeaveTime(str) { const m = /^(\d{1,2}):(\d{2})/.exec(String(str)); if (!m) return 870; let h = +m[1]; if (h < 7) h += 12; return h * 60 + (+m[2]); }
  fmtLeaveTime(mins) { let h = Math.floor(mins / 60); const mm = mins % 60; if (h > 12) h -= 12; return h + ':' + (mm < 10 ? '0' + mm : mm); }
  parseRoster(text) {
    return String(text).split(/\r?\n/).map(l => l.trim()).filter(Boolean)
      .map(l => l.split(/[,;\t]/).map(p => p.trim()))
      .filter(p => p[0] && !/^(name|first|player|kid)s?\b/i.test(p[0]))
      .map(p => ({ name: p[0].replace(/\s+/g, ' '), age: parseInt(p[1], 10) || null, gender: /^f/i.test(p[2] || '') ? 'F' : (/^m/i.test(p[2] || '') ? 'M' : null) }));
  }
  doImport(rows) {
    const camp = this.camp(); if (!camp || !rows.length) return;
    const venue = camp.venues.find(v => v.id === this.state.venueSel) || camp.venues[0];
    if (!venue) { this.setState({ sheet: null, draft: {}, page: 'shape' }); return; }
    let di = 0;
    const kids = rows.map((r, i) => {
      const age = r.age || 9 + (i * 3) % 6;
      const base = { id: this.uid(), name: r.name, age, gender: r.gender || (i % 2 ? 'F' : 'M'), notes: '' };
      if (this.ageFits(venue, age)) { base.venueId = venue.id; base.group = di % venue.groups; base.rank = Math.floor(di / venue.groups) + 1; di++; }
      else { base.venueId = null; base.group = null; base.rank = null; }
      return base;
    });
    this.set(s => {
      const c = s.db.camps.find(x => x.id === s.db.activeCampId);
      c.kids = c.kids.filter(k => k.venueId && k.venueId !== venue.id).concat(kids);
      return { db: s.db, page: null, pageArg: null, tab: 'groups', venueSel: venue.id, sheet: null, draft: {} };
    });
    this.showToast(di + ' dealt into ' + venue.groups + ' groups' + (kids.length - di ? ' · ' + (kids.length - di) + ' unassigned' : ''));
  }
  shortName(k) { if (!k) return '?'; const p = k.name.split(' '); return p[0] + (p[1] ? ' ' + p[1].charAt(0) : ''); }
  tournVals() {
    const st = this.state, camp = this.camp();
    if (!camp) return {};
    const venues = camp.venues;
    const venue = venues.find(v => v.id === st.venueSel) || venues[0] || null;
    const vals = {
      tabIsTourn: st.tab === 'tourn',
      pageInbox: st.page === 'inbox',
      openInbox: () => this.setState({ page: 'inbox' })
    };
    if (st.tab !== 'tourn') return vals;
    const ladder = venue ? this.ladderOf(camp, venue) : [];
    const tourn = venue ? ((camp.tournaments || {})[venue.id] || null) : null;
    vals.tMeta = ladder.length + ' kids on the ladder';
    vals.tNoVenue = !venue;
    vals.tNoKids = !!venue && ladder.length === 0;
    vals.tSetup = !!venue && ladder.length > 0 && !tourn;
    vals.tLive = !!tourn;
    if (vals.tSetup) {
      const fm = st.tFormat || 'singles';
      const meta = { singles: ['ph ph-user', 'Singles', 'Everyone plays for themselves'], doubles: ['ph ph-users', 'Doubles', 'Pairs — requested first, then by skill'], team: ['ph ph-users-three', 'Team tennis', 'Balanced teams, a coach on each'] };
      vals.formatRows = ['singles', 'doubles', 'team'].map((f, i) => ({
        icon: meta[f][0], title: meta[f][1], sub: meta[f][2],
        tileBg: fm === f ? '#EDF6F1' : '#F1F2F5', tileColor: fm === f ? '#14684A' : '#5C6068',
        line: i ? '1px solid #F2F3F6' : '0',
        on: fm === f, off: fm !== f,
        pick: () => this.setState({ tFormat: f, tCount: null, pendPairA: null })
      }));
      const minC = fm === 'team' ? 2 : 1;
      const cnt = Math.max(minC, st.tCount || 2);
      vals.tCount = cnt;
      vals.tCountLabel = fm === 'team' ? 'Teams' : 'Tournaments';
      vals.tDec = () => this.setState({ tCount: Math.max(minC, cnt - 1) });
      vals.tInc = () => this.setState({ tCount: Math.min(8, cnt + 1) });
      const req = st.reqPairs || [];
      if (fm === 'singles') vals.tPartitionHint = this.bandSizes(ladder.length, cnt).join(' · ') + ' kids per draw — bands by rank, top band first.';
      if (fm === 'doubles') { const pairsTotal = req.length + Math.ceil((ladder.length - req.length * 2) / 2); vals.tPartitionHint = pairsTotal + ' pairs → ' + this.bandSizes(pairsTotal, cnt).join(' · ') + ' per draw, seeded by rank for even matchups.'; }
      if (fm === 'team') vals.tPartitionHint = 'Snake draft by rank — every team gets a full spread. Assign coaches after.';
      vals.tIsDoubles = fm === 'doubles';
      const pairedIds = {};
      req.forEach(p => { pairedIds[p[0]] = true; pairedIds[p[1]] = true; });
      const kmap = {}; camp.kids.forEach(k => { kmap[k.id] = k; });
      vals.hasReqPairs = req.length > 0;
      vals.reqPairChips = req.map((p, i) => ({ label: this.shortName(kmap[p[0]]) + ' + ' + this.shortName(kmap[p[1]]), remove: () => this.setState({ reqPairs: req.filter((x, j) => j !== i) }) }));
      vals.pairHint = st.pendPairA ? 'Now tap ' + this.shortName(kmap[st.pendPairA]) + '\u2019s partner.' : 'Tap two kids to pair them — everyone else pairs by skill.';
      vals.unpairedChips = ladder.filter(k => !pairedIds[k.id]).map(k => {
        const on = st.pendPairA === k.id;
        return { label: this.shortName(k), bg: on ? '#0B0B0C' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #0B0B0C' : '1.5px solid #E4E5E9',
          pick: () => { const a = this.state.pendPairA; if (!a) this.setState({ pendPairA: k.id }); else if (a === k.id) this.setState({ pendPairA: null }); else this.setState({ reqPairs: (this.state.reqPairs || []).concat([[a, k.id]]), pendPairA: null }); } };
      });
      vals.tCreateCta = fm === 'singles' ? ('Draw ' + cnt + (cnt === 1 ? ' tournament' : ' tournaments')) : fm === 'doubles' ? ('Pair up · draw ' + cnt) : ('Make ' + cnt + ' teams');
      vals.tCreate = () => this.createTournament(fm, cnt);
    }
    if (tourn) {
      const kmap = {}; camp.kids.forEach(k => { kmap[k.id] = k; });
      const fmtLabel = { singles: 'Singles', doubles: 'Doubles', team: 'Team tennis' }[tourn.format];
      const n = tourn.format === 'team' ? tourn.teams.length : tourn.groups.length;
      vals.tSummary = fmtLabel + ' · ' + n + (tourn.format === 'team' ? ' teams' : (n === 1 ? ' tournament' : ' tournaments'));
      vals.tStartOverLabel = st.confirmTournClear ? 'Tap again to clear' : 'Start over';
      vals.tStartOver = () => {
        if (!this.state.confirmTournClear) { this.setState({ confirmTournClear: true }); setTimeout(() => this.setState({ confirmTournClear: false }), 2600); return; }
        this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); delete c.tournaments[venue.id]; return { db: s.db, confirmTournClear: false }; });
      };
      const FOLD = 9;
      const mkCard = (title, rows, i, extra) => {
        const key = 'T' + i, expanded = !!st.expanded[key];
        const visible = (expanded || rows.length <= FOLD) ? rows : rows.slice(0, FOLD - 1);
        return Object.assign({
          title, count: rows.length + (extra && extra.pairs ? (rows.length === 1 ? ' pair' : ' pairs') : (rows.length === 1 ? ' kid' : ' kids')),
          rows: visible.map((r, ri) => ({ num: ri + 1, label: r.label, pin: !!r.pin })),
          moreLabel: rows.length > FOLD ? (expanded ? 'Show fewer' : '+' + (rows.length - (FOLD - 1)) + ' more') : null,
          moreIcon: expanded ? 'ph ph-caret-up' : 'ph ph-caret-down',
          toggleMore: () => this.setState(s => ({ expanded: Object.assign({}, s.expanded, { [key]: !expanded }) })),
          showCoaches: false, noCoachYet: false
        }, extra || {});
      };
      if (tourn.format === 'team') {
        vals.tCards = tourn.teams.map((t, i) => {
          const rows = t.ids.map(id => kmap[id]).filter(Boolean).map(k => ({ label: k.name }));
          const staff = camp.staff || [];
          return mkCard(t.name, rows, i, {
            showCoaches: staff.length > 0,
            noCoachYet: staff.length === 0,
            coachPicks: staff.map(nm => {
              const on = (t.coaches || []).includes(nm);
              return { name: nm, bg: on ? '#1A7F55' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #1A7F55' : '1.5px solid #E4E5E9',
                pick: () => this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); const tm = c.tournaments[venue.id].teams[i]; tm.coaches = (tm.coaches || []).includes(nm) ? tm.coaches.filter(x => x !== nm) : (tm.coaches || []).concat(nm); return { db: s.db }; }) };
            })
          });
        });
      } else if (tourn.format === 'doubles') {
        vals.tCards = tourn.groups.map((g, i) => mkCard('Tournament ' + (i + 1), g.map(p => ({ label: p.ids.map(id => this.shortName(kmap[id])).join(' + ') + (p.ids.length === 1 ? ' · bye' : ''), pin: p.req })).filter(r => r.label.indexOf('?') !== 0), i, { pairs: true }));
      } else {
        vals.tCards = tourn.groups.map((g, i) => mkCard('Tournament ' + (i + 1) + (i === 0 ? ' · top band' : ''), g.map(id => kmap[id]).filter(Boolean).map(k => ({ label: k.name })), i));
      }
    }
    return vals;
  }
  createTournament(fm, cnt) {
    const camp = this.camp();
    const venue = camp.venues.find(v => v.id === this.state.venueSel) || camp.venues[0];
    const ladder = this.ladderOf(camp, venue);
    const data = { format: fm, count: cnt };
    if (fm === 'singles') {
      const sizes = this.bandSizes(ladder.length, cnt); let p = 0;
      data.groups = sizes.map(sz => { const b = ladder.slice(p, p + sz).map(k => k.id); p += sz; return b; });
    } else if (fm === 'doubles') {
      const idx = {}; ladder.forEach((k, i) => { idx[k.id] = i; });
      const req = this.state.reqPairs || [];
      const inReq = {}; req.forEach(p => { inReq[p[0]] = true; inReq[p[1]] = true; });
      const rest = ladder.filter(k => !inReq[k.id]);
      const pairs = req.map(p => ({ ids: p.slice(), req: true, seed: (idx[p[0]] + idx[p[1]]) / 2 }));
      for (let i = 0; i < rest.length; i += 2) {
        const ids = rest[i + 1] ? [rest[i].id, rest[i + 1].id] : [rest[i].id];
        pairs.push({ ids, req: false, seed: ids.length === 2 ? (idx[ids[0]] + idx[ids[1]]) / 2 : idx[ids[0]] });
      }
      pairs.sort((a, b) => a.seed - b.seed);
      const sizes = this.bandSizes(pairs.length, cnt); let p = 0;
      data.groups = sizes.map(sz => { const b = pairs.slice(p, p + sz).map(x => ({ ids: x.ids, req: x.req })); p += sz; return b; });
    } else {
      data.teams = Array.from({ length: cnt }, (_, i) => ({ name: 'Team ' + (i + 1), coaches: [], ids: [] }));
      ladder.forEach((k, i) => { const round = Math.floor(i / cnt); let pos = i % cnt; if (round % 2) pos = cnt - 1 - pos; data.teams[pos].ids.push(k.id); });
    }
    this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.tournaments = c.tournaments || {}; c.tournaments[venue.id] = data; return { db: s.db, tFormat: null, tCount: null, reqPairs: [], pendPairA: null }; });
    this.showToast(fm === 'team' ? cnt + ' teams drafted by rank' : 'Draw seeded by rank');
  }
  ageFits(venue, age) { const ag = venue && venue.ageGroup; if (ag === 'under11') return age <= 11; if (ag === 'up12') return age >= 12; return true; }
  ageLabel(v) { return v.ageGroup === 'under11' ? '11 & under' : v.ageGroup === 'up12' ? '12 & up' : 'All ages'; }
  assignKid(kidId, venue) {
    if (!venue) return;
    this.set(s => {
      const c = s.db.camps.find(x => x.id === s.db.activeCampId);
      const k = c.kids.find(y => y.id === kidId); if (!k) return { db: s.db };
      const g = venue.groups - 1;
      const end = c.kids.filter(y => y.venueId === venue.id && y.group === g).length;
      k.venueId = venue.id; k.group = g; k.rank = end + 1;
      return { db: s.db, q: '' };
    });
    this.showToast('Added to ' + venue.name + ' · Group ' + venue.groups);
  }
  kidAwayOn(k, label) { return (k.awayDays || (k.away ? ['Today'] : [])).includes(label); }
  dayLabelT(d) { return d === 1 ? 'Today' : 'Day ' + d; }
  rrMatches(ents) {
    const ids = ents.map(e => e.id); if (ids.length < 2) return [];
    const arr = ids.slice(); if (arr.length % 2) arr.push(null);
    const n = arr.length, rounds = n - 1, half = n / 2, ms = [];
    let rot = arr.slice(1);
    for (let r = 0; r < rounds; r++) {
      const left = [arr[0]].concat(rot.slice(0, half - 1));
      const right = rot.slice(half - 1).reverse();
      for (let i = 0; i < half; i++) { if (left[i] && right[i]) ms.push({ id: 'm' + (ms.length + 1), round: r + 1, a: left[i], b: right[i] }); }
      rot.unshift(rot.pop());
    }
    return ms;
  }
  drawMatches(ents) {
    const n = ents.length; if (n < 2) return [];
    let size = 1; while (size < n) size *= 2;
    const seeds = ents.map(e => e.id);
    const ms = []; const r1 = [];
    for (let i = 0; i < size / 2; i++) r1.push({ id: 'm' + (i + 1), round: 1, a: seeds[i] || null, b: seeds[size - 1 - i] || null });
    ms.push.apply(ms, r1);
    let prev = r1, mc = r1.length, r = 2;
    while (prev.length > 1) {
      const cur = [];
      for (let i = 0; i < prev.length; i += 2) { mc++; cur.push({ id: 'm' + mc, round: r, a: { w: prev[i].id }, b: { w: prev[i + 1].id } }); }
      ms.push.apply(ms, cur); prev = cur; r++;
    }
    return ms;
  }
  tournVals2() {
    const st = this.state, camp = this.camp();
    if (!camp) return {};
    const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0] || null;
    const vals = { tabIsTourn: st.tab === 'tourn', pageInbox: st.page === 'inbox', openInbox: () => this.setState({ page: 'inbox' }) };
    if (st.tab !== 'tourn') return vals;
    const ladder = venue ? this.ladderOf(camp, venue) : [];
    let list = venue ? ((camp.tournaments || {})[venue.id] || []) : [];
    if (!Array.isArray(list)) list = [];
    vals.tMeta = ladder.length + ' kids on the ladder';
    vals.tNoVenue = !venue;
    vals.tNoKids = !!venue && ladder.length === 0;
    vals.tEmpty = !!venue && ladder.length > 0 && list.length === 0;
    vals.tHasList = list.length > 0;
    vals.openNewTourney = () => this.setState({ sheet: 'tourney', draft: { kind: 'singles', mode: 'rr', tGroups: [0], days: 2, teams: 2, reqPairs: [] } });
    const kmap = {}; camp.kids.forEach(k => { kmap[k.id] = k; });
    vals.tCards2 = list.map((t, ti) => this.tCard(camp, venue, t, ti, kmap));
    return vals;
  }
  tCard(camp, venue, t, ti, kmap) {
    const st = this.state;
    const emap = {}; (t.entrants || []).forEach(e => { emap[e.id] = e; });
    const label = (eid) => { const e = emap[eid]; return e ? e.ids.map(id => this.shortName(kmap[id])).join(' + ') : '?'; };
    const card = {
      title: t.name,
      chips: [t.kind === 'singles' ? 'Singles' : t.kind === 'doubles' ? 'Doubles' : 'Team tennis', t.kind === 'team' ? ((t.teams || []).length + ' teams') : (t.mode === 'rr' ? 'Round robin' : 'Draw'), t.days + (t.days === 1 ? ' day' : ' days'), 'Group ' + t.groups.map(g => g + 1).join('+')].map(c => ({ c })),
      removeLabel: st.confirmTRemove === t.id ? 'Tap again' : 'Remove',
      remove: () => {
        if (this.state.confirmTRemove !== t.id) { this.setState({ confirmTRemove: t.id }); setTimeout(() => this.setState({ confirmTRemove: null }), 2600); return; }
        this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.tournaments[venue.id] = c.tournaments[venue.id].filter(x => x.id !== t.id); return { db: s.db, confirmTRemove: null }; });
      },
      isTeam: t.kind === 'team', notTeam: t.kind !== 'team'
    };
    if (t.kind === 'team') {
      const staff = camp.staff || [];
      card.teamCards = (t.teams || []).map((tm, i) => ({
        name: tm.name,
        count: tm.ids.filter(id => kmap[id]).length + ' kids',
        names: tm.ids.map(id => kmap[id]).filter(Boolean).map(k => this.shortName(k)).join(' · '),
        showCoaches: staff.length > 0,
        line: i ? '1px solid #F2F3F6' : '0',
        coachPicks: staff.map(nm => { const on = (tm.coaches || []).includes(nm); return { name: nm, bg: on ? '#1A7F55' : '#fff', color: on ? '#fff' : '#3F4A44', border: on ? '1.5px solid #1A7F55' : '1.5px solid #E4E5E9', pick: () => this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); const tt = c.tournaments[venue.id].find(x => x.id === t.id).teams[i]; tt.coaches = (tt.coaches || []).includes(nm) ? tt.coaches.filter(x => x !== nm) : (tt.coaches || []).concat(nm); return { db: s.db }; }) }; })
      }));
      card.teamNote = 'Team matchups come later — rosters and coaches for now.';
      return card;
    }
    const scores = t.scores || {};
    const self = this;
    function resolve(ref) { return typeof ref === 'string' ? ref : (ref && ref.w ? winnerOf(ref.w) : null); }
    function winnerOf(mid) {
      const m = t.matches.find(x => x.id === mid); if (!m) return null;
      if (m.a && !m.b) return resolve(m.a);
      if (!m.a && m.b) return resolve(m.b);
      const sc = scores[mid]; if (!sc) return null;
      const A = resolve(m.a), B = resolve(m.b); if (!A || !B) return null;
      return sc[0] > sc[1] ? A : B;
    }
    const roundsArr = []; t.matches.forEach(m => { if (roundsArr.indexOf(m.round) < 0) roundsArr.push(m.round); });
    roundsArr.sort((a, b) => a - b);
    const perDay = Math.max(1, Math.ceil(roundsArr.length / t.days));
    const baseDayOf = (round) => Math.floor(roundsArr.indexOf(round) / perDay) + 1;
    const awayOn = (eid, day) => { const e = emap[eid]; return !!e && e.ids.some(id => kmap[id] && this.kidAwayOn(kmap[id], this.dayLabelT(day))); };
    const playable = t.matches.filter(m => m.a && m.b);
    const disp = playable.map(m => {
      const base = baseDayOf(m.round);
      const A = resolve(m.a), B = resolve(m.b);
      let day = base, flag = null;
      const parts = [A, B].filter(Boolean);
      if (parts.length) {
        const badAt = (dd) => parts.filter(eid => awayOn(eid, dd)).map(label);
        const bad0 = badAt(base);
        if (bad0.length) {
          let found = null;
          const startDay = t.mode === 'rr' ? 1 : base;
          for (let dd = startDay; dd <= t.days; dd++) { if (!badAt(dd).length) { found = dd; break; } }
          if (found != null) { if (found !== base) { day = found; flag = 'Moved — ' + bad0.join(', ') + ' away ' + this.dayLabelT(base); } }
          else flag = bad0.join(', ') + ' away — walkover risk';
        }
      }
      let leaveMin = 9999;
      parts.forEach(eid => { emap[eid].ids.forEach(id => { const k = kmap[id]; if (!k || day !== 1) return; const lv = this.getLeaves(k).find(x => x.day === 'Today'); if (lv) leaveMin = Math.min(leaveMin, this.parseLeaveTime(lv.time)); }); });
      return { m, day, flag, leaveMin, A, B };
    });
    disp.sort((x, y) => x.day - y.day || x.leaveMin - y.leaveMin || x.m.round - y.m.round || (x.m.id > y.m.id ? 1 : -1));
    const numMap = {}; disp.forEach((x, i) => { numMap[x.m.id] = 'M' + (i + 1); });
    const selDay = (st.tDaySel || {})[t.id] || 1;
    card.dayPills = Array.from({ length: t.days }, (_, i) => { const dd = i + 1, on = selDay === dd; return { label: this.dayLabelT(dd), bg: on ? '#0B0B0C' : '#F1F2F5', color: on ? '#fff' : '#5C6068', pick: () => this.setState(s => ({ tDaySel: Object.assign({}, s.tDaySel, { [t.id]: dd }) })) }; });
    const dayList = disp.filter(x => x.day === selDay);
    const FOLD = 10, key = 'OP' + t.id, expanded = !!st.expanded[key];
    const vis = (expanded || dayList.length <= FOLD) ? dayList : dayList.slice(0, FOLD - 1);
    const upNextM = (dayList.find(x => !scores[x.m.id] && x.A && x.B) || { m: null }).m;
    card.matches = vis.map(x => {
      const sc = scores[x.m.id];
      const nameOf = (eid, ref) => eid ? label(eid) : ('Winner of ' + (ref && ref.w ? (numMap[ref.w] || 'earlier') : '…'));
      const aN = nameOf(x.A, x.m.a), bN = nameOf(x.B, x.m.b);
      const isNext = !!upNextM && upNextM.id === x.m.id;
      return {
        num: numMap[x.m.id], label: aN + ' vs ' + bN,
        labelColor: sc ? '#71757E' : '#0B0B0C',
        pad: isNext ? '8px 10px' : '8px 0',
        mar: isNext ? '4px -8px' : '0',
        ring: isNext ? '1.5px solid #C3DFCF' : '0',
        bt: isNext ? '1.5px solid #C3DFCF' : '1px solid #F2F3F6',
        rad: isNext ? '11px' : '0',
        bg: isNext ? '#F6FAF7' : 'transparent',
        score: sc ? (sc[0] + '–' + sc[1]) : null,
        scoreBtn: (!sc && x.A && x.B) ? 'Score' : null,
        flag: x.flag,
        open: () => { if (x.A && x.B) this.setState({ sheet: 'score', draft: { tid: t.id, mid: x.m.id, sa: sc ? sc[0] : 0, sb: sc ? sc[1] : 0, aN, bN } }); }
      };
    });
    card.moreLabel = dayList.length > FOLD ? (expanded ? 'Show fewer' : '+' + (dayList.length - (FOLD - 1)) + ' more') : null;
    card.moreIcon = expanded ? 'ph ph-caret-up' : 'ph ph-caret-down';
    card.toggleMore = () => this.setState(s => ({ expanded: Object.assign({}, s.expanded, { [key]: !expanded }) }));
    card.playedLine = Object.keys(scores).length + ' of ' + playable.length + ' played';
    if (t.mode === 'draw') {
      card.isDraw = true;
      const byRound = {}; t.matches.forEach(m => { (byRound[m.round] = byRound[m.round] || []).push(m); });
      const roundName = (i) => { const fromEnd = roundsArr.length - 1 - i; return fromEnd === 0 ? 'Final' : fromEnd === 1 ? 'Semis' : fromEnd === 2 ? 'Quarters' : 'Round of ' + byRound[roundsArr[i]].length * 2; };
      card.bracketCols = roundsArr.map((rd, i) => ({
        name: roundName(i),
        boxes: byRound[rd].map(m => {
          const A = resolve(m.a), B = resolve(m.b);
          const sc = scores[m.id];
          const nm = (eid, ref) => eid ? label(eid) : (ref && ref.w ? 'Winner of ' + (numMap[ref.w] || '…') : 'bye');
          const aW = sc ? sc[0] > sc[1] : (!!m.a && !m.b);
          const bW = sc ? sc[1] > sc[0] : (!m.a && !!m.b);
          return {
            aName: nm(A, m.a), bName: nm(B, m.b),
            aStyle: aW ? '600' : '500', bStyle: bW ? '600' : '500',
            aColor: aW ? '#14684A' : (A ? '#0B0B0C' : '#A2A6AE'), bColor: bW ? '#14684A' : (B ? '#0B0B0C' : '#A2A6AE'),
            aScore: sc ? String(sc[0]) : '', bScore: sc ? String(sc[1]) : '',
            tap: () => { if (A && B) this.setState({ sheet: 'score', draft: { tid: t.id, mid: m.id, sa: sc ? sc[0] : 0, sb: sc ? sc[1] : 0, aN: label(A), bN: label(B) } }); }
          };
        })
      }));
    }
    if (t.mode === 'rr') {
      const wl = {}; (t.entrants || []).forEach(e => { wl[e.id] = [0, 0]; });
      playable.forEach(m => { const sc = scores[m.id]; if (!sc) return; const A = resolve(m.a), B = resolve(m.b); if (!A || !B) return; if (sc[0] > sc[1]) { wl[A][0]++; wl[B][1]++; } else { wl[B][0]++; wl[A][1]++; } });
      const order = (t.entrants || []).slice().sort((a, b) => (wl[b.id][0] - wl[a.id][0]) || (wl[a.id][1] - wl[b.id][1]));
      const sKey = 'ST' + t.id, sExp = !!st.expanded[sKey];
      const allPlayed = playable.length > 0 && playable.every(m => scores[m.id]);
      card.isRR = true;
      card.standingsTitle = allPlayed ? 'Final standings' : 'Standings';
      card.standings = (sExp ? order : order.slice(0, 3)).map((e, i) => ({ num: i + 1, label: label(e.id), wl: wl[e.id][0] + '–' + wl[e.id][1], w: (i === 0 && allPlayed) ? '600' : '500', win: i === 0 && allPlayed }));
      card.standingsMore = order.length > 3 ? (sExp ? 'Show fewer' : 'Full standings · ' + order.length) : null;
      card.toggleStandings = () => this.setState(s => ({ expanded: Object.assign({}, s.expanded, { [sKey]: !sExp }) }));
    }
    return card;
  }
  createTourney2() {
    const st = this.state, camp = this.camp(), d = st.draft;
    const venue = camp.venues.find(v => v.id === st.venueSel) || camp.venues[0];
    const groupsSel = (d.tGroups && d.tGroups.length ? d.tGroups : [0]).slice().sort();
    const pool = this.ladderOf(camp, venue).filter(k => groupsSel.indexOf(k.group) >= 0);
    if (!pool.length) return;
    const listT = (camp.tournaments || {})[venue.id];
    const t = { id: this.uid(), kind: d.kind || 'singles', mode: d.mode || 'rr', groups: groupsSel, days: d.days || 1, scores: {}, name: 'Tournament ' + ((Array.isArray(listT) ? listT.length : 0) + 1) };
    if (t.kind === 'team') {
      const cnt = d.teams || 2;
      t.teams = Array.from({ length: cnt }, (_, i) => ({ name: 'Team ' + (i + 1), coaches: [], ids: [] }));
      pool.forEach((k, i) => { const round = Math.floor(i / cnt); let pos = i % cnt; if (round % 2) pos = cnt - 1 - pos; t.teams[pos].ids.push(k.id); });
      t.entrants = []; t.matches = [];
    } else {
      let entrants;
      if (t.kind === 'singles') entrants = pool.map(k => ({ id: 'e' + k.id, ids: [k.id] }));
      else {
        const idx = {}; pool.forEach((k, i) => { idx[k.id] = i; });
        const req = (d.reqPairs || []).filter(p => idx[p[0]] != null && idx[p[1]] != null);
        const inReq = {}; req.forEach(p => { inReq[p[0]] = true; inReq[p[1]] = true; });
        const rest = pool.filter(k => !inReq[k.id]);
        const prs = req.map(p => ({ ids: p.slice(), req: true, seed: (idx[p[0]] + idx[p[1]]) / 2 }));
        for (let i = 0; i + 1 < rest.length; i += 2) prs.push({ ids: [rest[i].id, rest[i + 1].id], req: false, seed: (idx[rest[i].id] + idx[rest[i + 1].id]) / 2 });
        prs.sort((a, b) => a.seed - b.seed);
        entrants = prs.map((p, i) => ({ id: 'e' + i + 'p', ids: p.ids, req: p.req }));
      }
      t.entrants = entrants;
      t.matches = t.mode === 'rr' ? this.rrMatches(entrants) : this.drawMatches(entrants);
    }
    this.set(s => { const c = s.db.camps.find(x => x.id === s.db.activeCampId); c.tournaments = c.tournaments || {}; const cur = c.tournaments[venue.id]; c.tournaments[venue.id] = (Array.isArray(cur) ? cur : []).concat([t]); return { db: s.db, sheet: null, draft: {} }; });
    this.showToast(t.name + (t.kind === 'team' ? ' · teams drafted' : ' · order of play drawn'));
  }
  campTabVals() {
    const st = this.state, camp = this.camp();
    if (!camp) return {};
    const kids = camp.kids.length;
    const coaches = Array.from(new Set([].concat.apply(camp.staff || [], camp.venues.map(v => v.coaches || []))));
    return {
      pageCamp: st.page === 'camp',
      profileBack: ({ overview: 'Overview', schedule: 'Schedule', groups: 'Groups', tourn: 'Tournament' })[st.tab] || 'Back',
      seasonLabel: camp.season || 'Season not set',
      kidChip: kids + ' kids',
      venueSummary: camp.venues.length ? camp.venues.map(v => v.name).join(' + ') + ' · ' + camp.venues.reduce((a, v) => a + v.courts, 0) + ' courts' : 'None yet — start here',
      kidsSummary: kids ? kids + ' across ' + camp.venues.reduce((a, v) => a + v.groups, 0) + ' groups' : 'None yet — import after shaping',
      canImport: camp.venues.length > 0,
      openImport: () => this.setState({ sheet: 'import', draft: { paste: '' } }),
      staffSummary: coaches.length ? coaches.join(', ') : 'Coaches join with the invite code',
      inviteCode: camp.code,
      goShape: () => this.setState({ page: 'shape' }),
      goKidsRow: () => this.setState({ tab: 'groups', page: null }),
      goSeason: () => this.setState({ sheet: 'season', draft: { name: camp.name, subtitle: camp.season } }),
      goCamps: () => this.setState({ page: 'camps' }),
      campCount: st.db.camps.length + (st.db.camps.length === 1 ? ' camp' : ' camps'),
      signOut: () => this.set(s => { s.db.signedIn = false; return { db: s.db, page: null, pageArg: null, sheet: null, authStep: null, authCode: '' }; }),
      signedEmail: st.db.email || '',
      pageShape: st.page === 'shape',
      shapeVenues: camp.venues.map(v => ({
        initial: (v.name || '?').slice(0, 1).toUpperCase(), name: v.name, subtitle: v.subtitle || null,
        courtsChip: v.courts + (v.courts === 1 ? ' court' : ' courts'),
        groupsChip: v.groups + (v.groups === 1 ? ' group' : ' groups'),
        targetChip: v.target ? '~' + v.target + '/group' : null,
        coachChip: (v.coaches && v.coaches.length) ? v.coaches.join(' + ') : 'No coaches yet',
        coachBg: (v.coaches && v.coaches.length) ? '#F1F2F5' : '#FBF2E2',
        coachColor: (v.coaches && v.coaches.length) ? '#5C6068' : '#8A5E0F',
        ageChip: this.ageLabel(v),
        edit: () => this.setState({ sheet: 'venue', draft: { venueId: v.id, name: v.name, subtitle: v.subtitle || '', courts: v.courts, groups: v.groups, target: v.target || 0, coaches: (v.coaches || []).slice(), coachInput: '', ageGroup: v.ageGroup || 'all' } })
      })),
      openNewVenue: () => this.setState({ sheet: 'venue', draft: { name: '', subtitle: '', courts: 4, groups: 3, target: 0, coaches: [], coachInput: '', ageGroup: 'all' } }),
      shapeCta: camp.venues.length > 0 && kids === 0
    };
  }
}
