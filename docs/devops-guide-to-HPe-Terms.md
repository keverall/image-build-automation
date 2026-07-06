# DevOps Guide to HPE Terms: Maintenance Mode vs. Disable vs. iLO vs. OneView

<a id="top"></a>
## Table of Contents

- [1. Monitoring Software vs. The Actual Hardware](#1-monitoring-software-vs-the-actual-hardware)
- [2. HPE iLO vs. HPE OneView (Note: "OpenView" is now OneView)](#2-hpe-ilo-vs-hpe-oneview-note-openview-is-now-oneview)
- [3. Where does SCOM fit into this?](#3-where-does-scom-fit-into-this)
  - [SCOM Maintenance Mode](#scom-maintenance-mode)
- [Summary of the Flow](#summary-of-the-flow)
- [The Sneaky Exception: iLO's Own Maintenance Mode](#the-sneaky-exception-ilos-own-maintenance-mode)
  - [1. You cannot manually put iLO into Maintenance Mode](#1-you-cannot-manually-put-ilo-into-maintenance-mode)
  - [2. If iLO is in Maintenance Mode, it means it is broken](#2-if-ilo-is-in-maintenance-mode-it-means-it-is-broken)


HPE and Microsoft love to reuse words like "maintenance mode," but they mean entirely different things depending on whether you are looking at the **physical hardware** or the **monitoring software**.

putting a server into maintenance mode in your monitoring software (like HPE OneView or SCOM) does not impact the actual physical server’s operation. It is purely a way to stop the alarms from screaming while you do work.

Here is the breakdown of how these pieces fit together and what those terms actually mean in each context.

---

<a name="1-monitoring-software-vs-the-actual-hardware"></a>
## 1. Monitoring Software vs. The Actual Hardware

When you change a status to "Maintenance Mode" or "Disable" in monitoring software, you are essentially putting noise-canceling headphones on your alerting system.

* **The Impact:** Zero impact on the actual server hardware or OS. The server keeps running, Windows/Linux stays up, and users can still log in.
* **The Purpose:** It tells the monitoring tool: *"I am intentionally working on this server right now. If it reboots or drops offline, do not page the on-call engineer or open an automated IT ticket."*

---

<a name="2-hpe-ilo-vs-hpe-oneview-note-openview-is-now-oneview"></a>
## 2. HPE iLO vs. HPE OneView (Note: "OpenView" is now OneView)

*Quick side note: HPE "OpenView" is an older legacy suite. The modern tool you are likely using for HPE hardware management is called **HPE OneView**.*

Here is how maintenance and disabling work across these two HPE tools:

| Feature/Term | Where it lives | What it actually does | Impact on Server? |
| --- | --- | --- | --- |
| **iLO (Integrated Lights-Out)** | **On the server itself** (Management chip) | The actual hardware management processor. If you disable a feature here (like disabling a network port or a power setting), **it can affect the physical server.** | **Yes** (Potentially) |
| **OneView Maintenance Mode** | **Central Management Software** | Tells OneView to stop pulling alerts or applying firmware compliance checks to that specific server blade/rack while you change parts or update it. | **No** |
| **OneView "Disable"** | **Central Management Software** | Usually refers to disabling a specific alert policy, a logical interconnect, or a server profile link. | **No** (Unless unassigning a profile) |

---

<a name="3-where-does-scom-fit-into-this"></a>
## 3. Where does SCOM fit into this?

**SCOM (Microsoft System Center Operations Manager)** is the ultimate "umbrella" monitoring system for your entire data center.

Think of the hierarchy like this:

1. **HPE iLO** watches the physical temperature, fans, and hard drives of *one* specific server.
2. **HPE OneView** talks to all your iLOs to manage your entire fleet of HPE hardware.
3. **SCOM** sits at the very top. It watches the Windows/Linux Operating Systems, the applications (like SQL or Exchange), **and** it hooks into HPE OneView to get hardware alerts.

<a name="scom-maintenance-mode"></a>
### SCOM Maintenance Mode

If you put a server into Maintenance Mode in SCOM, you are telling SCOM: *"Stop watching the Windows OS and applications on this box for the next hour."* Again, the server keeps running perfectly fine; SCOM just suppresses the alerts so your dashboard doesn't turn bright red when you reboot it for Windows Updates.

---

<a name="summary-of-the-flow"></a>
## Summary of the Flow

Imagine you need to replace a bad stick of RAM in an HPE server:

1. You put the server into **Maintenance Mode in SCOM and HPE OneView** (Turns off alerts so nobody panics).
2. You gracefully shut down the Windows OS.
3. You log into **HPE iLO** to virtually power off the box and check the physical health.
4. You swap the RAM, turn it back on, and verify it's healthy in iLO.
5. You take the server **out of Maintenance Mode** in OneView and SCOM so it starts actively monitoring for real failures again.


<a name="the-sneaky-exception-ilos-own-maintenance-mode"></a>
## The Sneaky Exception: iLO's Own Maintenance Mode

There is one sneaky exception with **iLO** that you need to watch out for!

While "Maintenance Mode" in **OneView** and **SCOM** strictly means *"stop sending alerts to humans,"* 

**HPE iLO actually has its own version of Maintenance Mode, and it works completely differently.**

Here is the distinction:

<a name="1-you-cannot-manually-put-ilo-into-maintenance-mode"></a>
### 1. You cannot manually put iLO into Maintenance Mode

In SCOM or OneView, you click a button to turn Maintenance Mode on. In iLO, there is no button for you to do this.

<a name="2-if-ilo-is-in-maintenance-mode-it-means-it-is-broken"></a>
### 2. If iLO is in Maintenance Mode, it means it is broken

If you log into an HPE server's iLO interface and see a banner that says **"iLO is in Maintenance Mode,"** it means the iLO management chip itself has experienced a critical self-test failure (usually a corrupted flash memory chip/NAND).

When iLO drops into its own internal Maintenance Mode:

* **The Production Server keeps running:** Your operating system (Windows/Linux) and applications will usually keep running just fine.
* **Management is lost:** You lose the ability to use the remote console, check temperatures, or monitor fan speeds through the iLO web interface.

**The Key Takeaway:**

* **SCOM & OneView Maintenance Mode:** A *good* thing you do intentionally to pause alerts while you work.

* **iLO Maintenance Mode:** A *bad* hardware state that iLO forces itself into when its internal management chip is failing.
