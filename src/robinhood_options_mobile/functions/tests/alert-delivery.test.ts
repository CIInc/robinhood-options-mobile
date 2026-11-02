import { describe, it, expect } from "@jest/globals";
import {
  isWithinQuietHours,
  resolveChannelAndSound,
  dispatchMultiChannelAlert,
  UserNotificationCustomizationSettings,
} from "../src/alert-delivery";
import { shouldNotifyUser } from "../src/trade-signal-notifications";

describe("Alert delivery & customization helper", () => {
  it("evaluates overnight quiet hours and respects critical bypass", () => {
    const settings: UserNotificationCustomizationSettings = {
      quietHoursEnabled: true,
      quietHoursStartHour: 22,
      quietHoursEndHour: 7,
      bypassQuietHoursForCritical: true,
    };

    const lateNight = new Date("2026-08-27T23:30:00Z");
    const earlyMorning = new Date("2026-08-27T05:15:00Z");
    const midDay = new Date("2026-08-27T14:00:00Z");

    expect(isWithinQuietHours(settings, "high", lateNight)).toBe(true);
    expect(isWithinQuietHours(settings, "standard", earlyMorning)).toBe(true);
    expect(isWithinQuietHours(settings, "high", midDay)).toBe(false);
    // Critical bypasses quiet hours when bypassQuietHoursForCritical is true
    expect(isWithinQuietHours(settings, "critical", lateNight)).toBe(false);

    // Disable bypass
    expect(
      isWithinQuietHours(
        { ...settings, bypassQuietHoursForCritical: false },
        "critical",
        lateNight
      )
    ).toBe(true);
  });

  it("resolves priority channels, custom sounds, and overrides", () => {
    const settings: UserNotificationCustomizationSettings = {
      priorityChannel: "high",
      alertSound: "chime",
      vibrate: true,
      signalSoundOverrides: {
        BUY: "pulse",
        GEX: "radar",
      },
      deliveryChannels: ["push", "in_app", "email"],
    };

    const buyDelivery = resolveChannelAndSound("BUY", settings);
    expect(buyDelivery.channelId).toBe("trade_signals");
    expect(buyDelivery.sound).toBe("pulse");
    expect(buyDelivery.apnsInterruptionLevel).toBe("time-sensitive");
    expect(buyDelivery.channels).toEqual(["push", "in_app", "email"]);

    // High confidence (>= 0.85) escalates to critical_alerts
    const highConfBuy = resolveChannelAndSound("BUY", settings, undefined, 0.9);
    expect(highConfBuy.channelId).toBe("critical_alerts");
    expect(highConfBuy.priority).toBe("critical");
    expect(highConfBuy.apnsInterruptionLevel).toBe("critical");

    // Per-alert override takes precedence over user settings
    const customOverride = resolveChannelAndSound("CUSTOM", settings, {
      priority: "standard",
      sound: "bell",
      channels: ["push", "sms"],
    });
    expect(customOverride.channelId).toBe("custom_alerts");
    expect(customOverride.sound).toBe("bell");
    expect(customOverride.channels).toEqual(["push", "sms"]);

    // Silent sound routes to silent_digest channel with undefined sound
    const silentOverride = resolveChannelAndSound("FLOW", settings, {
      priority: "low",
      sound: "silent",
    });
    expect(silentOverride.channelId).toBe("silent_digest");
    expect(silentOverride.sound).toBeUndefined();
    expect(silentOverride.vibrate).toBe(false);
    expect(silentOverride.apnsInterruptionLevel).toBe("passive");
  });

  it("dispatches external channels and enforces critical gating", async () => {
    const addedDocs: Record<string, unknown[]> = {
      mail_queue: [],
      sms_queue: [],
      webhook_queue: [],
    };
    const fakeDb = {
      collection: (name: string) => ({
        add: async (doc: unknown) => {
          addedDocs[name] = addedDocs[name] || [];
          addedDocs[name].push(doc);
          return { id: "mock-id" };
        },
      }),
    } as unknown as FirebaseFirestore.Firestore;

    const settings: UserNotificationCustomizationSettings = {
      deliveryChannels: ["push", "in_app", "email", "sms", "webhook"],
      emailAddress: "trader@example.com",
      phoneNumber: "+15551234567",
      webhookUrl: "https://example.com/webhook",
      criticalOnlyExternalChannels: true,
    };

    // Standard priority (0.65 conf) is gated out when criticalOnly is true
    const standardResolved = resolveChannelAndSound(
      "BUY",
      settings,
      { priority: "standard", channels: settings.deliveryChannels },
      0.65
    );
    const skipped = await dispatchMultiChannelAlert(fakeDb, {
      userId: "user-1",
      category: "BUY",
      symbol: "AAPL",
      title: "BUY AAPL",
      body: "Daily • 65% Conf.",
      confidence: 0.65,
      settings,
      resolved: standardResolved,
    });
    expect(skipped).toEqual([]);
    expect(addedDocs.mail_queue.length).toBe(0);

    // High confidence (0.88) or critical priority dispatches to external queues
    const criticalResolved = resolveChannelAndSound(
      "BUY",
      settings,
      { priority: "critical", channels: settings.deliveryChannels },
      0.88
    );
    const delivered = await dispatchMultiChannelAlert(fakeDb, {
      userId: "user-1",
      category: "BUY",
      symbol: "NVDA",
      title: "BUY NVDA @ $135.00",
      body: "Daily • 88% Conf.",
      confidence: 0.88,
      settings,
      resolved: criticalResolved,
    });
    expect(delivered).toEqual(["email", "sms", "webhook"]);
    expect(addedDocs.mail_queue.length).toBe(1);
    expect(addedDocs.sms_queue.length).toBe(1);
    expect(addedDocs.webhook_queue.length).toBe(1);
  });
});

describe("shouldNotifyUser per-signal & indicator customization", () => {
  const baseSettings = {
    enabled: true,
    signalTypes: ["BUY", "SELL"],
    symbols: [],
    intervals: ["1d"],
    includeHold: false,
  };

  it("filters by requiredIndicators when configured", () => {
    const signalWithRsiAndMacd = {
      timestamp: Date.now(),
      symbol: "AAPL",
      interval: "1d",
      signal: "BUY",
      multiIndicatorResult: {
        allGreen: false,
        overallSignal: "BUY",
        reason: "Momentum breakout",
        signalStrength: 80,
        indicators: {
          priceMovement: { value: 1, signal: "HOLD", reason: "" },
          momentum: { value: 28, signal: "BUY", reason: "RSI oversold" },
          marketDirection: { value: 1, signal: "BUY", reason: "" },
          volume: { value: 1, signal: "HOLD", reason: "" },
          macd: { value: 0.5, signal: "SELL", reason: "" },
          bollingerBands: { value: 1, signal: "HOLD", reason: "" },
          stochastic: { value: 1, signal: "HOLD", reason: "" },
          atr: { value: 1, signal: "HOLD", reason: "" },
          obv: { value: 1, signal: "HOLD", reason: "" },
          vwap: { value: 1, signal: "HOLD", reason: "" },
          adx: { value: 1, signal: "HOLD", reason: "" },
          williamsR: { value: 1, signal: "HOLD", reason: "" },
        },
      },
    };

    // Requires momentum -> matches BUY
    expect(
      shouldNotifyUser(signalWithRsiAndMacd, {
        ...baseSettings,
        requiredIndicators: ["momentum"],
      })
    ).toBe(true);

    // Requires macd -> macd is SELL, signal is BUY -> does not match
    expect(
      shouldNotifyUser(signalWithRsiAndMacd, {
        ...baseSettings,
        requiredIndicators: ["macd"],
      })
    ).toBe(false);
  });

  it("respects priceTriggerEnabled and gexTriggerEnabled toggles", () => {
    const gexSignal = {
      timestamp: Date.now(),
      symbol: "SPY",
      interval: "1d",
      signal: "BUY",
      reason: "GEX Call Wall breakout",
      indicators: {
        gex: { value: 1, signal: "BUY", reason: "Positive gamma flip" },
      },
    };

    expect(
      shouldNotifyUser(gexSignal, {
        ...baseSettings,
        gexTriggerEnabled: false,
      })
    ).toBe(false);

    expect(
      shouldNotifyUser(gexSignal, {
        ...baseSettings,
        gexTriggerEnabled: true,
        priceTriggerEnabled: false,
      })
    ).toBe(true);
  });
});
