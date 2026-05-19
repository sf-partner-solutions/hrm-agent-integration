import { LightningElement, api } from 'lwc';

const RECOMMENDATIONS = {
    UPSELL: [
        {
            emoji: '🎯',
            title: 'Tighten audience segmentation',
            body: 'Data360 trends show 38% of offers go to travelers already holding the ancillary. Add a "Has_Active_Lounge_Membership" exclusion node before Offer_Lounge_Access to lift effective conversion.'
        },
        {
            emoji: '⏰',
            title: 'Re-time offers to T-72h',
            body: 'Open rate peaks 72 hours pre-departure (Amadeus operations data). Shift the 30d branch to a scheduled T-72h path for an estimated +18% conversion lift.'
        },
        {
            emoji: '💰',
            title: 'Personalize price by loyalty tier',
            body: 'Tier strongly predicts willingness-to-pay. Add a Loyalty_Tier branch — apply a 15% premium for Platinum and a 10% discount for non-members.'
        },
        {
            emoji: '🌍',
            title: 'Localize offer copy',
            body: 'Conversion drops 22% on non-English routes. Add a Locale decision and route to translated message templates from the Data360 content library.'
        },
        {
            emoji: '🤝',
            title: 'Bundle low-converters with high-converters',
            body: 'Trip Insurance converts at 3.2% solo, 11% bundled with Premium Seat. Replace the standalone insurance offer with a bundle assignment.'
        }
    ],
    CART_RETARGETING: [
        {
            emoji: '⚡',
            title: 'Trigger faster on abandonment',
            body: 'Industry data shows 60% of cart recovery happens within the first hour. Lower the wait from 24h to 1h for an estimated 2× recovery rate.'
        },
        {
            emoji: '🎁',
            title: 'Offer a small loyalty incentive',
            body: 'Adding a 500-mile bonus to the re-engagement message lifts conversion 31% (Data360 benchmark). Add an Apply_Incentive assignment after the consent check.'
        },
        {
            emoji: '📱',
            title: 'Add SMS fallback',
            body: 'Email open rate is 24% in this cohort vs 87% on SMS. Add an SMS branch for travelers with mobile consent in their Account record.'
        },
        {
            emoji: '🧠',
            title: 'Suppress fatigued contacts',
            body: '14% of contacts received 4+ messages in the last 7 days. Tighten Fatigue_Check threshold from < 3 to < 2 to protect deliverability.'
        }
    ],
    VISA: [
        {
            emoji: '🛂',
            title: 'Expand restricted-country list',
            body: 'Five destinations miss recent visa-policy changes (UK, AU, AE, JP, KR). Add them to the Visa_Required decision rule to avoid silent gaps.'
        },
        {
            emoji: '📅',
            title: 'Send 14 days before departure',
            body: 'Travelers act on visa notices 11 days out on average. Add a Wait_Until_T-14d pause node so the notice lands in the action window.'
        },
        {
            emoji: '🤖',
            title: 'AI-personalize the notice copy',
            body: 'Generic visa notices have a 41% read rate; AI-personalized copy hits 73%. Swap Build_Visa_Notice for a Prompt-Template-driven assignment.'
        },
        {
            emoji: '✅',
            title: 'Add a follow-up confirmation',
            body: 'Add a Has_Visa decision 7 days after the initial notice and nudge non-responders. Reduces day-of denials by 60%.'
        }
    ],
    SURVEY: [
        {
            emoji: '⏱️',
            title: 'Send within 24h of arrival',
            body: 'Recall accuracy drops 50% after 48h. Trigger immediately on Trip_Completed instead of the next-day batch — biggest single completion-rate driver.'
        },
        {
            emoji: '✂️',
            title: 'Cap survey to 3 questions',
            body: 'Completion rate doubles when surveys have ≤ 3 questions. Replace Pick_Long_Survey body with a 3-question variant for non-VIPs.'
        },
        {
            emoji: '🎁',
            title: 'Offer a 200-mile thank-you',
            body: 'Incentivized surveys hit 62% completion vs 24% baseline. Add an Award_Miles assignment after Mark_Surveyed.'
        },
        {
            emoji: '🌐',
            title: 'Translate for top 5 markets',
            body: 'Non-English completion is 11% vs 38% English. Add a Locale branch and reuse the Data360 translation service for top 5 origins.'
        }
    ],
    CUSTOM: [
        {
            emoji: '🔍',
            title: 'Refine entry segmentation',
            body: 'Data360 shows the entry audience is too broad. Add a pre-flow filter to focus on travelers who already engaged in the last 30 days.'
        },
        {
            emoji: '✨',
            title: 'AI-personalize messaging',
            body: 'Adopt the Data360 prompt-template service to personalize copy per traveler segment. Average +28% engagement uplift across journeys.'
        }
    ]
};

const THINKING_MS = 1600;
const TYPE_TITLE_MS = 18;
const TYPE_BODY_MS = 8;
const NEXT_REC_GAP_MS = 220;

export default class JourneyOptimizationAgent extends LightningElement {
    @api journeyApiName;
    @api journeyLabel;
    @api category;

    isThinking = true;
    recs = [];
    timers = [];

    connectedCallback() {
        const list = (RECOMMENDATIONS[this.category] || RECOMMENDATIONS.CUSTOM).map((r, i) => ({
            id: `rec-${i}`,
            emoji: r.emoji,
            title: r.title,
            body: r.body,
            typedTitle: '',
            typedBody: '',
            isTypingTitle: false,
            isTypingBody: false,
            isDone: false,
            visible: false,
            applied: false
        }));
        this.recs = list;

        const t = setTimeout(() => {
            this.isThinking = false;
            this.streamRec(0);
        }, THINKING_MS);
        this.timers.push(t);
    }

    disconnectedCallback() {
        this.timers.forEach((t) => clearTimeout(t));
        this.timers = [];
    }

    streamRec(index) {
        if (index >= this.recs.length) return;
        const updated = this.recs.map((r, i) => (i === index ? { ...r, visible: true, isTypingTitle: true } : r));
        this.recs = updated;
        this.typeText(index, 'title', 0);
    }

    typeText(index, field, charIndex) {
        const rec = this.recs[index];
        if (!rec) return;
        const fullText = field === 'title' ? rec.title : rec.body;
        const typedKey = field === 'title' ? 'typedTitle' : 'typedBody';
        const speed = field === 'title' ? TYPE_TITLE_MS : TYPE_BODY_MS;

        if (charIndex > fullText.length) {
            // Done with this field.
            if (field === 'title') {
                const advance = this.recs.map((r, i) =>
                    i === index ? { ...r, isTypingTitle: false, isTypingBody: true } : r
                );
                this.recs = advance;
                this.typeText(index, 'body', 0);
            } else {
                const finish = this.recs.map((r, i) => (i === index ? { ...r, isTypingBody: false, isDone: true } : r));
                this.recs = finish;
                const t = setTimeout(() => this.streamRec(index + 1), NEXT_REC_GAP_MS);
                this.timers.push(t);
            }
            return;
        }

        const next = this.recs.map((r, i) =>
            i === index ? { ...r, [typedKey]: fullText.substring(0, charIndex) } : r
        );
        this.recs = next;

        const t = setTimeout(() => this.typeText(index, field, charIndex + 1), speed);
        this.timers.push(t);
    }

    get displayedRecs() {
        return this.recs.filter((r) => r.visible).map((r) => {
            const isCurrentlyTyping = r.isTypingTitle || r.isTypingBody;
            return {
                ...r,
                cardClass: r.applied ? 'rec-card rec-card-applied' : 'rec-card',
                acceptDisabled: r.applied || !r.isDone,
                showTitleCursor: r.isTypingTitle,
                showBodyCursor: r.isTypingBody,
                showAcceptButton: r.isDone && !r.applied,
                showAppliedBadge: r.applied,
                stillTyping: isCurrentlyTyping
            };
        });
    }

    get hasAnyDisplayed() {
        return this.recs.some((r) => r.visible);
    }

    get pendingCount() {
        return this.recs.filter((r) => r.isDone && !r.applied).length;
    }

    get acceptAllDisabled() {
        return this.pendingCount === 0;
    }

    get journeySubtitle() {
        return this.journeyLabel || 'Journey';
    }

    handleAccept(event) {
        const recId = event.currentTarget.dataset.id;
        this.recs = this.recs.map((r) => (r.id === recId ? { ...r, applied: true } : r));
    }

    handleAcceptAll() {
        const appliedCount = this.recs.filter((r) => r.isDone && !r.applied).length;
        this.recs = this.recs.map((r) => (r.isDone ? { ...r, applied: true } : r));
        this.dispatchEvent(
            new CustomEvent('applyall', {
                detail: { appliedCount, journeyApiName: this.journeyApiName }
            })
        );
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleBackdropClick(event) {
        if (event.target.classList.contains('agent-backdrop')) {
            this.handleClose();
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }
}
