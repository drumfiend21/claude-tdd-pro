# Plain-Language Architecture Explanation - 2026-06-08T12:00:00Z

What the technical terms in your options mean, in business terms:

- **access_control**: decide who is allowed to do what in the system (why it matters: keeps the wrong people away from sensitive actions and data) [source: nist-800-53]
- **automated_failover**: automatically switch to a healthy backup when the primary fails (why it matters: customers stay served without waiting for a human to react) [source: aws-reliability-pillar]
- **autoscaling**: add and remove capacity automatically as demand changes (why it matters: stays fast under load and you only pay for what you use) [source: aws-well-architected]
- **caching**: keep frequently used data close by for quick reuse (why it matters: faster responses for customers and lower cost) [source: aws-well-architected]
- **encryption_at_rest**: scramble stored data so it is unreadable if storage is stolen (why it matters: protects customer data and meets compliance obligations) [source: nist-800-53]
- **encryption_in_transit**: scramble data while it travels between systems (why it matters: stops anyone in the middle from reading sensitive information) [source: nist-800-53]
- **health_check**: continuously test whether each component is actually working (why it matters: lets the system route around broken parts before customers notice) [source: aws-reliability-pillar]
- **monitoring**: watch the systems health signals continuously (why it matters: you catch and fix problems before they reach customers) [source: google-sre-book]
- **multi_az**: run copies in separate data centers in the same region (why it matters: one data-center outage will not take your service down) [source: aws-reliability-pillar]
- **multi_region**: run the system in more than one geographic region (why it matters: survives even a whole-region outage for the highest resilience) [source: aws-reliability-pillar]
