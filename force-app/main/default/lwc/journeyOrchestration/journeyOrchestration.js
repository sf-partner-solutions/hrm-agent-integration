import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getJourneys from '@salesforce/apex/JourneyOrchestrationController.getJourneys';
import getTemplates from '@salesforce/apex/JourneyOrchestrationController.getTemplates';

const STAT_PRESETS = {
    CART_RETARGETING: { launched: 520, actioned: 278, converted: 74, altConverted: 18, blocks: 6, tags: ['marketing', 'conversion', 'cart'] },
    UPSELL:           { launched: 380, actioned: 215, converted: 55, altConverted: 12, blocks: 6, tags: ['upsell', 'ancillary', 'revenue'] },
    VISA:             { launched: 340, actioned: 210, converted: 87, altConverted: null, blocks: 5, tags: ['visa', 'compliance', 'notification', 'operational'] },
    SURVEY:           { launched: 180, actioned: 95,  converted: 42, altConverted: null, blocks: 5, tags: ['survey', 'feedback', 'loyalty', 'post-trip'] },
    CUSTOM:           { launched: 200, actioned: 110, converted: 40, altConverted: null, blocks: 4, tags: ['custom'] }
};

const TEMPLATE_META = {
    JOT_Cart_Retargeting:           { icon: '🛒', steps: ['open-cart', 'n-fatigue-score', 'n-consent', '+3 more'] },
    JOT_Post_Booking_Upsell:        { icon: '⬆',  steps: ['order-created', 'n-fatigue-score', 'n-order-status', '+3 more'] },
    JOT_Churn_Risk_Reengagement:    { icon: '👤', steps: ['churn-risk', 'n-previous-notifications', 'inspirational', '+2 more'] }
};

const CATEGORY_LABELS = {
    CART_RETARGETING: 'CART RETARGETING',
    UPSELL: 'UPSELL',
    VISA: 'CUSTOM',
    SURVEY: 'CUSTOM',
    CUSTOM: 'CUSTOM'
};

const CATEGORY_ICONS = {
    CART_RETARGETING: '🛒',
    UPSELL: '⬆',
    VISA: '⚙',
    SURVEY: '⚙',
    CUSTOM: '⚙'
};

const DATE_FMT = new Intl.DateTimeFormat('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });

export default class JourneyOrchestration extends NavigationMixin(LightningElement) {
    journeysRaw;
    templatesRaw;
    journeysWired;
    templatesWired;
    searchTerm = '';
    typeFilter = 'all';

    typeOptions = [
        { label: 'All types', value: 'all' },
        { label: 'Cart Retargeting', value: 'CART_RETARGETING' },
        { label: 'Upsell', value: 'UPSELL' },
        { label: 'Custom', value: 'CUSTOM' }
    ];

    isOptimizeOpen = false;
    optimizeJourney = null;

    @wire(getJourneys)
    wiredJourneys(result) {
        this.journeysWired = result;
        if (result.data) {
            this.journeysRaw = result.data;
        }
    }

    @wire(getTemplates)
    wiredTemplates(result) {
        this.templatesWired = result;
        if (result.data) {
            this.templatesRaw = result.data;
        }
    }

    get totalJourneys() {
        return (this.journeysRaw || []).length;
    }

    get activeCount() {
        return (this.journeysRaw || []).filter((j) => j.isActive).length;
    }

    get draftCount() {
        return (this.journeysRaw || []).filter((j) => !j.isActive).length;
    }

    get filteredJourneys() {
        const list = this.journeysRaw || [];
        const term = (this.searchTerm || '').toLowerCase();
        return list
            .filter((j) => this.typeFilter === 'all' || j.category === this.typeFilter)
            .filter((j) => !term || (j.label || '').toLowerCase().includes(term) || (j.description || '').toLowerCase().includes(term))
            .map((j) => this.decorateJourney(j));
    }

    get filteredTemplates() {
        return (this.templatesRaw || []).map((t) => this.decorateTemplate(t));
    }

    get hasJourneys() {
        return this.filteredJourneys.length > 0;
    }

    get hasTemplates() {
        return this.filteredTemplates.length > 0;
    }

    decorateJourney(j) {
        const stats = STAT_PRESETS[j.category] || STAT_PRESETS.CUSTOM;
        const cleanedDescription = this.stripCategoryTag(j.description) || 'Automated journey driven by traveler triggers.';
        const total = stats.launched || 1;
        const actionedW = (stats.actioned / total) * 100;
        const convertedW = (stats.converted / total) * 100;
        const altW = stats.altConverted ? (stats.altConverted / total) * 100 : 0;
        const launchedRemainW = Math.max(0, 100 - actionedW - convertedW - altW);
        const funnelStyle = `background: linear-gradient(to right,
            #16A34A 0%,
            #16A34A ${convertedW}%,
            #F59E0B ${convertedW}%,
            #F59E0B ${convertedW + altW}%,
            #7C3AED ${convertedW + altW}%,
            #7C3AED ${convertedW + altW + actionedW}%,
            #1F2937 ${convertedW + altW + actionedW}%,
            #1F2937 100%);`;
        return {
            ...j,
            categoryLabel: CATEGORY_LABELS[j.category] || 'CUSTOM',
            categoryIcon: CATEGORY_ICONS[j.category] || '⚙',
            statusLabel: j.isActive ? 'Active' : 'Draft',
            statusClass: j.isActive ? 'status-pill status-active' : 'status-pill status-draft',
            cleanedDescription,
            blocksLabel: `${stats.blocks} blocks`,
            modifiedLabel: this.formatDate(j.lastModifiedDate),
            launched: stats.launched,
            launchedPct: this.pct(stats.launched, stats.launched),
            actioned: stats.actioned,
            actionedPct: this.pct(stats.actioned, stats.launched),
            converted: stats.converted,
            convertedPct: this.pct(stats.converted, stats.launched),
            altConverted: stats.altConverted,
            altConvertedPct: stats.altConverted ? this.pct(stats.altConverted, stats.launched) : null,
            hasAltConverted: stats.altConverted !== null && stats.altConverted !== undefined,
            funnelStyle,
            tags: stats.tags
        };
    }

    decorateTemplate(t) {
        const meta = TEMPLATE_META[t.apiName] || { icon: '⚙', steps: ['custom-step'] };
        return {
            ...t,
            templateIcon: meta.icon,
            cleanedDescription: this.stripCategoryTag(t.description) || 'Reusable journey template.',
            steps: meta.steps
        };
    }

    stripCategoryTag(text) {
        if (!text) return '';
        return text.replace(/\[category:[A-Z_]+\]/g, '').trim();
    }

    pct(part, total) {
        if (!total) return '0%';
        return `${((part / total) * 100).toFixed(1)}%`;
    }

    formatDate(value) {
        if (!value) return '—';
        try {
            return DATE_FMT.format(new Date(value));
        } catch (e) {
            return '—';
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleTypeChange(event) {
        this.typeFilter = event.target.value;
    }

    handleNewJourney() {
        window.open('/lightning/setup/Flows/home', '_blank', 'noopener');
    }

    handleEditJourney(event) {
        const flowId = event.currentTarget.dataset.flowid;
        if (!flowId) {
            window.open('/lightning/setup/Flows/home', '_blank', 'noopener');
            return;
        }
        window.open(`/builder_platform_interaction/flowBuilder.app?flowId=${flowId}`, '_blank', 'noopener');
    }

    handleUseTemplate(event) {
        const flowId = event.currentTarget.dataset.flowid;
        if (!flowId) {
            window.open('/lightning/setup/Flows/home', '_blank', 'noopener');
            return;
        }
        window.open(`/builder_platform_interaction/flowBuilder.app?flowId=${flowId}`, '_blank', 'noopener');
    }

    handleRefresh() {
        if (this.journeysWired) refreshApex(this.journeysWired);
        if (this.templatesWired) refreshApex(this.templatesWired);
    }

    handleOptimize(event) {
        const { apiname, label, category } = event.currentTarget.dataset;
        this.optimizeJourney = { apiName: apiname, label, category };
        this.isOptimizeOpen = true;
    }

    handleOptimizeClose() {
        this.isOptimizeOpen = false;
        this.optimizeJourney = null;
    }

    handleOptimizeApplyAll(event) {
        const count = (event && event.detail && event.detail.appliedCount) || 0;
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Recommendations queued',
                message: `${count} optimization${count === 1 ? '' : 's'} queued for deployment to flow draft`,
                variant: 'success'
            })
        );
        setTimeout(() => this.handleOptimizeClose(), 600);
    }
}
