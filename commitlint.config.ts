import type { UserConfig } from "@commitlint/types";

// This config follows the project guidelines
// (https://docs.google.com/document/d/1psbMtN-PIF4oBbNc_pW_mtDPPAa_yPdV_apf-wq5spM/edit?tab=t.0)

const config: UserConfig = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "scope-empty": [2, "never"],
    "scope-max-length": [2, "always", 20],

    // Subject rules
    "subject-max-length": [2, "always", 50],
    "subject-case": [2, "always", "sentence-case"],
    "subject-full-stop": [2, "never", "."],

    // Body rules
    "body-empty": [0],
    "body-max-line-length": [2, "always", 72],

    // Footer (optional)
    "footer-max-line-length": [2, "always", 72],
  },

  prompt: {
    settings: {
      enableMultipleScopes: false,
    },
    messages: {
      skip: ":skip (press enter to skip)",
      max: "Max %d characters",
      min: "Min %d characters",
      emptyWarning: "This field cannot be empty",
      upperLimitWarning: "Character limit exceeded",
      lowerLimitWarning: "Too few characters",
    },
    questions: {
      type: {
        description: "Select the type of change you're committing:",
        enum: {
          feat: {
            description: "✨ A new feature",
            title: "Feature",
            emoji: "✨",
          },
          fix: {
            description: "🐛 A bug fix",
            title: "Bug Fix",
            emoji: "🐛",
          },
          docs: {
            description: "📚 Documentation only changes",
            title: "Documentation",
            emoji: "📚",
          },
          style: {
            description:
              "💅 Changes that do not affect code meaning (formatting, etc.)",
            title: "Style",
            emoji: "💅",
          },
          refactor: {
            description:
              "🔧 Code change that neither fixes a bug nor adds a feature",
            title: "Refactor",
            emoji: "🔧",
          },
          test: {
            description: "✅ Adding or updating tests",
            title: "Test",
            emoji: "✅",
          },
          chore: {
            description: "🛠  Maintenance tasks (e.g., tooling, dependencies)",
            title: "Chore",
            emoji: "🛠",
          },
          perf: {
            description: "⚡ Performance improvement",
            title: "Performance",
            emoji: "⚡",
          },
          build: {
            description: "🏗 Build system or dependency changes",
            title: "Build",
            emoji: "🏗",
          },
          ci: {
            description: "🔁 CI/CD configuration",
            title: "CI",
            emoji: "🔁",
          },
          revert: {
            description: "⏪ Reverts a previous commit",
            title: "Revert",
            emoji: "⏪",
          },
        },
      },
      scope: {
        description: "Scope of this change (e.g., auth, ui, api)",
      },
      subject: {
        description:
          "Write a short, imperative description (max 50 chars, e.g., Add login validation)",
      },
      body: {
        description:
          "Provide a detailed description of what changed, why, and how (optional)",
      },
    },
  },
};

export default config;
