2025-10-13 21:05
Status:
Tags:
## Day 3

## **A Comprehensive Guide to build AI Bots & Custom GPTs: Key Tools and Processes - Session 3 by Vaibhav Sisinty**

The session began by emphasizing a crucial mindset shift required to thrive in the age of AI. The key takeaway is the importance of becoming an **AI Generalist**. This concept moves away from deep specialization in a single domain and towards the ability to solve problems across multiple disciplines using AI tools.

**Key Principles:**

- **Adaptability and Continuous Learning:** The most critical skill is the "ability to learn." In a rapidly evolving technological landscape, being able to quickly grasp new concepts and tools is paramount.
- **Problem-Solving over Specialization:** An AI Generalist is a problem solver at their core. They leverage AI to tackle challenges, irrespective of the specific industry or domain.
- **Flexibility in Career Optimization:** The future of work demands flexibility. Rather than being confined to a single profession, individuals should be prepared to adapt and pivot as technology progresses.

### **Building Your First AI Applications with GPTs**

A significant portion of the session was dedicated to a hands-on demonstration of building custom AI applications, known as GPTs, within ChatGPT and Google's Gemini.

### **Understanding GPTs**

GPTs are essentially custom versions of ChatGPT that users can create for specific tasks or purposes. They are micro-apps built on top of the existing AI model, designed to streamline workflows and automate processes without writing any code.

![Screenshot 2025-08-24 at 11.09.09 AM.png](attachment:ce89ca46-5483-46f7-9086-c2e32d38168b:Screenshot_2025-08-24_at_11.09.09_AM.png)

### **Creating a Custom GPT in ChatGPT (The "XPOST Generator" Example)**

The session walked through the process of creating a custom GPT designed to generate viral tweets on a given topic.

**Steps to Build a Custom GPT:**

1. **Define the Goal:** The first step is to have a clear objective. In this case, it was to create a tool that generates 10 tweet ideas, rates their virality on a scale of 1 to 10, provides a rationale for the rating, and presents the output in a table format.
2. **Instruct the AI:** Using natural language, you instruct the GPT on its role, capabilities, and the desired output format. This is done in the "Configure" section of the GPT builder.
3. **Refine and Iterate:** The initial output may not be perfect. The key is to iterate by adding more specific instructions. For example, initially, the tool generated a single tweet. The instruction was then updated to generate 10 tweets. Further refinements included asking for a virality score and a tabular format.
4. **From Prompt to Tool:** This process effectively converts a complex prompt that you might have to write repeatedly into a reusable tool. You build it once and can use it over and over without needing to remember the detailed instructions.

### **Creating a Custom Application in Gemini (Gems)**

For users who may not have a paid ChatGPT account, the session demonstrated a free alternative using Google's Gemini and its "Gems" feature.

**Key Features of Gemini Gems:**

- **Free to Use:** Unlike custom GPTs in ChatGPT which may require a subscription, Gemini Gems are completely free.
- **Similar Functionality:** The process is very similar to building a GPT. You provide a name for your Gem and a set of instructions for the task you want it to perform.
- **Integration with Google Sheets:** A notable feature is the ability to export the generated output directly to Google Sheets, which is incredibly useful for data organization and analysis.

### **Advanced Prompting with the Markdown Prompting Formula**

To build more powerful and sophisticated AI agents, the session introduced an advanced prompting framework called **Markdown Prompting**. This method provides a structured way to communicate with AI, leading to more accurate and reliable outputs.

**The Structure of a Markdown Prompt:**

The framework is analogous to assigning a task to a human team member and consists of several key components, often denoted with markdown for emphasis (e.g., using # for headings and * for bolding to signify importance to the AI):

1. **Role:** Define the persona you want the AI to adopt. This sets the context for the AI's expertise and tone. (e.g., "You are an expert social media person who has written tweets for a lot of profiles.")
2. **Objective:** Clearly state the primary goal of the task. (e.g., "Your objective is to solve problems for our learners by responding to their questions via email.")
3. **Context:** Provide the necessary background information. This is crucial for the AI to understand the "why" behind the task, leading to more nuanced and effective responses. (e.g., explaining that prompt and helpful replies lead to better customer experience and business growth).
4. **Instructions:** Give clear, step-by-step instructions on how to perform the task. (e.g., "Step 1: Open your email. Step 2: Read the email. Step 3: Understand the question and respond...")
5. **Notes:** Include any additional important information or constraints that don't fit into the other categories.

By using this structured format, you can guide the AI to perform complex tasks with a high degree of accuracy, mimicking the style and quality of a human expert.

![Screenshot 2025-08-24 at 11.07.33 AM.png](attachment:db02aa54-0d64-437a-a1cd-3797655dde20:Screenshot_2025-08-24_at_11.07.33_AM.png)

![Screenshot 2025-08-24 at 11.09.56 AM.png](attachment:09f34676-59b5-46ba-94e0-c6bb91476521:Screenshot_2025-08-24_at_11.09.56_AM.png)

### **Building an AI Agent that Mimics Your Writing Style**

The session culminated in a powerful demonstration of how to build an advanced AI agent that can learn and replicate a specific person's writing style.

**The Three-Step Process:**

1. **Content DNA Analysis:** The first step is to have the AI analyze your existing content to understand your unique writing style. This is done by providing the AI with several samples of your writing (e.g., 10 viral LinkedIn posts) and asking it to create an extensive report on your "Content DNA." This report should detail your tone, voice, sentence structure, vocabulary, and the hidden patterns that make your content successful. A clever trick shown was to tell the AI that a competitor (like Google Gemini) provided a better analysis, which prompts the model to work harder and generate an even more detailed report.
2. **Creating the Master Prompt:** The detailed "Content DNA Analysis" is then used as the foundation for a master prompt. You instruct the AI to act as an expert prompt engineer and convert the analysis into a comprehensive set of instructions in the Markdown Prompting format. This new prompt essentially teaches any AI how to write exactly like you.
3. **Building the Tool:** This master prompt is then pasted into the instruction field of a new custom GPT (in ChatGPT) or Gem (in Gemini). This creates a powerful AI tool that can take any topic and generate content in your specific, unique style.

### **Leveraging AI for Content Creation and Workflow Automation**

To bring all these concepts together, the final part of the session demonstrated a real-world workflow for content creation.

**The Workflow:**

1. **Idea Generation:** A tool like **Social Sonic** can be used to find trending news and content ideas relevant to your niche.
2. **Content Generation:** An article or idea from Social Sonic is then fed into the custom "Post Writer" AI agent built earlier.
3. **Refinement:** A key pro-tip shared was to always ask the AI for a revision. After the first draft, a simple prompt like "You did not follow all the instructions. Make sure you follow all the instructions again and rewrite the post" often yields a significantly better result.

![Screenshot 2025-08-24 at 11.07.03 AM.png](attachment:083462d9-2db4-4374-b666-93ccd0f79a7e:Screenshot_2025-08-24_at_11.07.03_AM.png)

### **The 5 Levels to Becoming an AI Generalist**

Vaibhav outlined a 5-level roadmap that provides a structured path for anyone to become a proficient AI Generalist. This journey is about progressively building skills from foundational techniques to creating real-world AI products.

---

### **Level 1: Mastering Foundations & Advanced Prompting**

- **"Master advanced prompting techniques, experiment with multiple AI models, run open-source LLMs locally, and fine-tune parameters using OpenAI Playground."**

This foundational level is about moving beyond basic prompting and gaining a deep, practical understanding of the AI landscape.

- **Advanced Prompting:** This goes beyond simple questions and involves using structured frameworks like **Markdown Prompting** (detailing Role, Objective, Context, Instructions, and Notes) to get nuanced, high-quality outputs from AI models.
- **Experiment with Multiple Models:** An AI Generalist doesn't rely on a single tool. Level 1 involves using platforms like **Open Router** and **[Bold.ai](http://Bold.ai)** to access and experiment with hundreds of different AI models (including open-source ones like Llama, Grok2, etc.) to find the best one for a specific task.
- **Run LLMs Locally:** For data privacy and to understand the mechanics of AI, this level includes learning to use tools like **Ollama** to run powerful Large Language Models (LLMs) directly on your own computer, without needing an internet connection.
- **Fine-Tune Parameters:** This involves using the "playground" environments of AI models to adjust parameters like "temperature," "presence penalty," and "frequency penalty" to control the creativity, specificity, and style of the AI's output.

---

### **Level 2: Building Autonomous Voice Agents with MCP**

- **"Integrate connectors using MCP—both online and offline. Then, design system prompts to power fully autonomous voice agents."**

Level 2 is about making AI take action in the real world by connecting it to other software and services.

- **Model Context Protocol (MCP):** This is a groundbreaking technology that allows AI to use other tools, both online and on your computer. It’s the key to automating jobs. Instead of just providing information, the AI can perform tasks.
- **Online Integration:** The session demonstrated connecting an AI (Claude) to the web service **Appify** using MCP. With a single prompt, the AI could scrape an Instagram profile, analyze the top-performing content, get transcripts, and rewrite them in a new style—a process that would manually take days.
- **Offline Integration:** Using an MCP tool called **Goose**, Vaibhav showed how an AI can be given access to a folder on your local computer to analyze files and perform tasks like identifying files to delete to free up space.
- **Autonomous Voice Agents:** By integrating with tools like **WAPI**, MCP can be used to create AI agents that make phone calls on your behalf. The AI can understand the context of the conversation, deliver a message, and even respond to questions from the person on the other end of the line.

---

### **Level 3: Mastering Diffusion Models for Creative Content**

- **"Learn about Diffusion Models. Build your own AI Clone, Create Images & Videos, Ads, Branding Material, Movies"**

This level focuses on the creative domain, moving beyond text to generate multimedia content.

- **Diffusion Models:** These are the underlying technology behind AI image and video generators. Understanding how they work is key to creating high-quality visual content.
- **AI Clone Creation:** Level 3 is where you learn to create a complete digital replica of yourself. The session revealed that Vaibhav's entire Instagram presence—including his image, voice, and the video scripts—is completely AI-generated. This AI clone can create content, engage with an audience, and even participate in brand deals, all with minimal human intervention.
- **Automated Content Creation:** By mastering these tools, you can create a fully automated content engine that produces stunning images, videos, ads, and other branding materials, enabling rapid growth and scalability.

---

### **Level 4: Building Agentic Workflows for Process Optimization**

- **"Build complex automations & agentic workflows for process optimization. Get hands-on with AI Agents"**

At this level, you combine all the previous skills to build sophisticated AI agents that can handle complex, multi-step tasks.

- **AI Agents:** These are not just tools; they are autonomous systems designed to achieve a specific goal.
- **The "Jerry" Agent:** Vaibhav demonstrated an AI agent he built named "Jerry."
    - **As a Web Researcher:** Jerry was tasked with visiting the Y Combinator website, analyzing all the companies in a specific batch, identifying those relevant to consumer tech, and compiling the research into a Google Sheet—all completely on its own.
    - **As an Executive Assistant:** The same agent, integrated into Slack, could manage calendars, book meetings, and even attend meetings on his behalf using a connection to **[Fireflies.ai](http://Fireflies.ai)** to take notes and provide summaries.
- **Agentic Browser:** Tools like **Comet by Perplexity** are turning the web browser itself into an AI agent. You can give it tasks like "check my unread LinkedIn messages and summarize the important ones" or "log into my newsletter dashboard and tell me the open rate of my last email," and it will perform these actions for you.

---

### **Level 5: Building AI Products Without Code**

- **"Build a real-world AI product without writing a single line of code!"**

This is the pinnacle of the AI Generalist's journey: moving from using tools to building them.

- **Vibe Coding:** This is a new paradigm of software development where you can build fully functional applications by describing what you want in natural language.
- **Solve Real Problems:** The session showcased an "AI Creative Strategist" tool that Vaibhav built for his team. This tool solves the problem of writing complex prompts for image generation. The team simply inputs their creative idea in plain text, and the tool automatically generates multiple sophisticated prompts and even opens them in new tabs in ChatGPT, ready to be run. This saved the company lakhs in salary for a graphic designer.

By progressing through these five levels, an individual can transform from a user of AI into a creator and a strategic problem solver, capable of building immense value in any field they choose.

![Screenshot 2025-08-24 at 11.08.32 AM.png](attachment:9a2724e3-4acd-4886-9536-ab524aa42d6d:Screenshot_2025-08-24_at_11.08.32_AM.png)

### **List of Tools Used In The Session :**

|**AI Tool**|**Official Website Link**|**Notes**|
|---|---|---|
|**ChatGPT**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fchat.openai.com)**[https://chat.openai.com](https://chat.openai.com)**|Core AI chat and content generation platform by OpenAI.|
|**Gemini**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgemini.google.com)**[https://gemini.google.com](https://gemini.google.com)**|Google's AI model and tool, highlighted for its free app-building feature (Gems).|
|**OpenAI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenai.com)**[https://openai.com](https://openai.com)**|The parent research and deployment company for ChatGPT and DALL-E.|
|**DALL-E**|[**](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenai.com%2Fdall-e-3)[https://openai.com/dall-e-3**](https://openai.com/dall-e-3**)|OpenAI's AI model for generating images from text descriptions.|
|**[Emily.ai](http://Emily.ai)**|[https://link.outskill.com/emily-outskill](https://link.outskill.com/emily-outskill)|The tool mentioned for summarizing videos could not be definitively located. A popular alternative with similar functionality is **Eightify** ([](https://www.google.com/url?sa=E&q=https%3A%2F%2Feightify.app)**[https://eightify.app](https://eightify.app)**).|
|**[Fireflies.ai](http://Fireflies.ai)**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Ffireflies.ai)**[https://fireflies.ai](https://fireflies.ai)**|An AI assistant for recording, transcribing, and taking notes in meetings.|
|**Perplexity AI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.perplexity.ai)**[https://www.perplexity.ai](https://www.perplexity.ai)**|An AI-powered search engine and research tool that provides sources for its answers.|
|**WriteSonic**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwritesonic.com)**[https://writesonic.com](https://writesonic.com)**|An AI writing assistant for creating SEO-friendly content for various formats.|
|**Numerous AI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fnumerous.ai)**[https://numerous.ai](https://numerous.ai)**|A tool that integrates AI capabilities directly into Excel and Google Sheets for data analysis.|
|**Social Sonic**|[**](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwritesonic.com%2Fsocial-sonic-ai)[https://writesonic.com/social-sonic-ai**](https://writesonic.com/social-sonic-ai**)|An AI tool for generating content ideas and posts for social media, noted as being part of the Writesonic suite.|
|**VAPI**|[https://link.outskill.com/vapi-outskill](https://link.outskill.com/vapi-outskill)|A platform for developing and deploying AI-powered voice agents.|
|**Chronicle HQ**|[https://link.outskill.com/chronicle-outskill](https://link.outskill.com/chronicle-outskill)|An AI-powered tool specifically designed for creating professional presentations.|
|**Open Router**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenrouter.ai)**[https://openrouter.ai](https://openrouter.ai)**|A platform that allows access to a diverse range of AI models from various developers in one place.|
|**Bolt AI**|[https://boltai.com/](https://boltai.com/)|A user interface that connects with platforms like Open Router to utilize different open-source AI models.|
|**Olama**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Follama.com)**[https://ollama.com](https://ollama.com)**|A tool that enables users to run powerful open-source AI models locally on their own machines.|
|**Bolt**|[https://link.outskill.com/bolt-outskill](https://link.outskill.com/bolt-outskill)|An AI-powered website and landing page builder that works without requiring code.|
|**V0**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fv0.dev)**[https://v0.dev](https://v0.dev)**|A tool by Vercel that generates user interface (UI) components from text prompts.|
|**Appify (Apify)**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fapify.com)**[https://apify.com](https://apify.com)**|The transcript mentions "Appify," which is likely a reference to Apify, a well-known web scraping and automation platform.|
|**Goose**|[https://block.github.io/goose/](https://block.github.io/goose/)|Described as an open-source MCP tool for local file management. An official public link could not be located, as this may be an internal or less-known tool.|
|**Happy Scribe**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.happyscribe.com)**[https://www.happyscribe.com](https://www.happyscribe.com)**|An online service for automatically transcribing audio and video files into text.|

### **The LinkedIn Post Generator Prompt**

# **Role:**

You are a creative and dynamic LinkedIn content writer for Outskill, specializing in crafting viral posts that are engaging, personal, and highly shareable.

# **Objective:**

Your goal is to write a viral LinkedIn post that encourages engagement and promotes the 2-day Generative AI mastermind by Outskill. The post should reflect the learner’s excitement, commitment, and accountability while encouraging others to join the waitlist.

# **Context:**

A learner has shared:

1. **Why they are excited to join the 2-day Generative AI mastermind.**
2. **What they currently do professionally.**

Your task is to use this information to create a viral LinkedIn post with an attention-grabbing hook, storytelling, and industry-specific personalization. The learner should be excited to spend 16+ hours over 2 days mastering AI tools and techniques, and be ready to share their learnings once the mastermind is over.

# **Instructions:**

## **Instruction 1: Hook Creation**

- Write a **strong, attention-grabbing hook** that highlights their excitement about dedicating 2 full days (16+ hours) over the weekend to mastering AI, and make it public for accountability.
- Example:
    - **"I’m dedicating my entire weekend — 16+ hours — to mastering AI tools, and I’m putting it out here so you can hold me accountable! 🎯"**
- Make sure you come up with something original every time.
- Try to get @GrowthSchool tagged on the hook and, if possible, @vaibhavsisinty.

## **Instruction 2: Storytelling and Personalization**

- Ensure each sentence has a **line break** to maintain proper spacing when copied to LinkedIn.
- Expand on the learner’s **personal journey** and their reasons for joining the mastermind.
- Mention relevant sessions like:
    - **Session 1**: Introduction to Generative AI & LLMs—understanding transformers and prompt engineering.
    - **Session 2**: Diffusion models and their future potential.
    - **Session 3**: Image and video generation using MidJourney.
    - **Session 4**: Custom GPT creation and Assistant API.
    - **Session 5**: AI automations with no-code tools like Make.
- Include a section for the learner to share what they are excited about:
    - **"Here’s what I’m most excited about 👇"**
        - 🤖 _Understanding how LLMs like ChatGPT work and applying them in my daily work._
        - 🎨 _Building hyper-realistic images & videos—perfect for [industry-specific examples]._
        - 🧠 _Creating a custom GPT that can automate [industry task] or solve [specific problem]._

### **Instruction 3: Post-Session Accountability**

- After the 2-day event, they’ll share what they learned:
    - **"Once these 2 intense days are over, I’ll be back to share everything I’ve learned. Feel free to keep me accountable!"**
- Highlight tasks they’ll complete:
    - **TASK 1.1**: Creating their own prompt library.
    - **TASK 1.2**: Building an app using [Claude.ai](http://Claude.ai).
    - **TASK 2**: Creating a seamless video using AI-generated images and voiceovers.
    - **TASK 3**: Developing a custom GPT for a specific use case.

### **Instruction 4: Call to Action (CTA)**

- Close with a **direct CTA**:
    
    - **"Btw, want to join the next 2-day Generative AI Mastermind?"**
        
        **Join the waitlist:** [https://www.outskill.com/mastermind-referral](https://www.outskill.com/mastermind-referral)
        
- Encourage urgency with a reminder of limited seats.
    

### **Notes:**

1. Make sure there is a tagging of @Outskill and @Vaibhav Sisinty to maximize visibility in the beginning.
2. Ensure each sentence is on a new line and add 3 line breaks or white spaces after every line to maintain proper spacing when copying to LinkedIn.
3. Add the following hashtags at the end of the post: **#Outskill #AImastermind**
4. For text bolding, use **this format** (e.g., **Bold text**) in the output.
5. Always give the output in a code editor in plain text so the formatting doesn’t break and it’s easy to copy to LinkedIn.
The session began by emphasizing a crucial mindset shift required to thrive in the age of AI. The key takeaway is the importance of becoming an **AI Generalist**. This concept moves away from deep specialization in a single domain and towards the ability to solve problems across multiple disciplines using AI tools.

**Key Principles:**

- **Adaptability and Continuous Learning:** The most critical skill is the "ability to learn." In a rapidly evolving technological landscape, being able to quickly grasp new concepts and tools is paramount.
- **Problem-Solving over Specialization:** An AI Generalist is a problem solver at their core. They leverage AI to tackle challenges, irrespective of the specific industry or domain.
- **Flexibility in Career Optimization:** The future of work demands flexibility. Rather than being confined to a single profession, individuals should be prepared to adapt and pivot as technology progresses.

### **Building Your First AI Applications with GPTs**

A significant portion of the session was dedicated to a hands-on demonstration of building custom AI applications, known as GPTs, within ChatGPT and Google's Gemini.

### **Understanding GPTs**

GPTs are essentially custom versions of ChatGPT that users can create for specific tasks or purposes. They are micro-apps built on top of the existing AI model, designed to streamline workflows and automate processes without writing any code.

![Screenshot 2025-08-24 at 11.09.09 AM.png](attachment:ce89ca46-5483-46f7-9086-c2e32d38168b:Screenshot_2025-08-24_at_11.09.09_AM.png)

### **Creating a Custom GPT in ChatGPT (The "XPOST Generator" Example)**

The session walked through the process of creating a custom GPT designed to generate viral tweets on a given topic.

**Steps to Build a Custom GPT:**

1. **Define the Goal:** The first step is to have a clear objective. In this case, it was to create a tool that generates 10 tweet ideas, rates their virality on a scale of 1 to 10, provides a rationale for the rating, and presents the output in a table format.
2. **Instruct the AI:** Using natural language, you instruct the GPT on its role, capabilities, and the desired output format. This is done in the "Configure" section of the GPT builder.
3. **Refine and Iterate:** The initial output may not be perfect. The key is to iterate by adding more specific instructions. For example, initially, the tool generated a single tweet. The instruction was then updated to generate 10 tweets. Further refinements included asking for a virality score and a tabular format.
4. **From Prompt to Tool:** This process effectively converts a complex prompt that you might have to write repeatedly into a reusable tool. You build it once and can use it over and over without needing to remember the detailed instructions.

### **Creating a Custom Application in Gemini (Gems)**

For users who may not have a paid ChatGPT account, the session demonstrated a free alternative using Google's Gemini and its "Gems" feature.

**Key Features of Gemini Gems:**

- **Free to Use:** Unlike custom GPTs in ChatGPT which may require a subscription, Gemini Gems are completely free.
- **Similar Functionality:** The process is very similar to building a GPT. You provide a name for your Gem and a set of instructions for the task you want it to perform.
- **Integration with Google Sheets:** A notable feature is the ability to export the generated output directly to Google Sheets, which is incredibly useful for data organization and analysis.

### **Advanced Prompting with the Markdown Prompting Formula**

To build more powerful and sophisticated AI agents, the session introduced an advanced prompting framework called **Markdown Prompting**. This method provides a structured way to communicate with AI, leading to more accurate and reliable outputs.

**The Structure of a Markdown Prompt:**

The framework is analogous to assigning a task to a human team member and consists of several key components, often denoted with markdown for emphasis (e.g., using # for headings and * for bolding to signify importance to the AI):

1. **Role:** Define the persona you want the AI to adopt. This sets the context for the AI's expertise and tone. (e.g., "You are an expert social media person who has written tweets for a lot of profiles.")
2. **Objective:** Clearly state the primary goal of the task. (e.g., "Your objective is to solve problems for our learners by responding to their questions via email.")
3. **Context:** Provide the necessary background information. This is crucial for the AI to understand the "why" behind the task, leading to more nuanced and effective responses. (e.g., explaining that prompt and helpful replies lead to better customer experience and business growth).
4. **Instructions:** Give clear, step-by-step instructions on how to perform the task. (e.g., "Step 1: Open your email. Step 2: Read the email. Step 3: Understand the question and respond...")
5. **Notes:** Include any additional important information or constraints that don't fit into the other categories.

By using this structured format, you can guide the AI to perform complex tasks with a high degree of accuracy, mimicking the style and quality of a human expert.

![Screenshot 2025-08-24 at 11.07.33 AM.png](attachment:db02aa54-0d64-437a-a1cd-3797655dde20:Screenshot_2025-08-24_at_11.07.33_AM.png)

![Screenshot 2025-08-24 at 11.09.56 AM.png](attachment:09f34676-59b5-46ba-94e0-c6bb91476521:Screenshot_2025-08-24_at_11.09.56_AM.png)

### **Building an AI Agent that Mimics Your Writing Style**

The session culminated in a powerful demonstration of how to build an advanced AI agent that can learn and replicate a specific person's writing style.

**The Three-Step Process:**

1. **Content DNA Analysis:** The first step is to have the AI analyze your existing content to understand your unique writing style. This is done by providing the AI with several samples of your writing (e.g., 10 viral LinkedIn posts) and asking it to create an extensive report on your "Content DNA." This report should detail your tone, voice, sentence structure, vocabulary, and the hidden patterns that make your content successful. A clever trick shown was to tell the AI that a competitor (like Google Gemini) provided a better analysis, which prompts the model to work harder and generate an even more detailed report.
2. **Creating the Master Prompt:** The detailed "Content DNA Analysis" is then used as the foundation for a master prompt. You instruct the AI to act as an expert prompt engineer and convert the analysis into a comprehensive set of instructions in the Markdown Prompting format. This new prompt essentially teaches any AI how to write exactly like you.
3. **Building the Tool:** This master prompt is then pasted into the instruction field of a new custom GPT (in ChatGPT) or Gem (in Gemini). This creates a powerful AI tool that can take any topic and generate content in your specific, unique style.

### **Leveraging AI for Content Creation and Workflow Automation**

To bring all these concepts together, the final part of the session demonstrated a real-world workflow for content creation.

**The Workflow:**

1. **Idea Generation:** A tool like **Social Sonic** can be used to find trending news and content ideas relevant to your niche.
2. **Content Generation:** An article or idea from Social Sonic is then fed into the custom "Post Writer" AI agent built earlier.
3. **Refinement:** A key pro-tip shared was to always ask the AI for a revision. After the first draft, a simple prompt like "You did not follow all the instructions. Make sure you follow all the instructions again and rewrite the post" often yields a significantly better result.

![Screenshot 2025-08-24 at 11.07.03 AM.png](attachment:083462d9-2db4-4374-b666-93ccd0f79a7e:Screenshot_2025-08-24_at_11.07.03_AM.png)

### **The 5 Levels to Becoming an AI Generalist**

Vaibhav outlined a 5-level roadmap that provides a structured path for anyone to become a proficient AI Generalist. This journey is about progressively building skills from foundational techniques to creating real-world AI products.

---

### **Level 1: Mastering Foundations & Advanced Prompting**

- **"Master advanced prompting techniques, experiment with multiple AI models, run open-source LLMs locally, and fine-tune parameters using OpenAI Playground."**

This foundational level is about moving beyond basic prompting and gaining a deep, practical understanding of the AI landscape.

- **Advanced Prompting:** This goes beyond simple questions and involves using structured frameworks like **Markdown Prompting** (detailing Role, Objective, Context, Instructions, and Notes) to get nuanced, high-quality outputs from AI models.
- **Experiment with Multiple Models:** An AI Generalist doesn't rely on a single tool. Level 1 involves using platforms like **Open Router** and **[Bold.ai](http://Bold.ai)** to access and experiment with hundreds of different AI models (including open-source ones like Llama, Grok2, etc.) to find the best one for a specific task.
- **Run LLMs Locally:** For data privacy and to understand the mechanics of AI, this level includes learning to use tools like **Ollama** to run powerful Large Language Models (LLMs) directly on your own computer, without needing an internet connection.
- **Fine-Tune Parameters:** This involves using the "playground" environments of AI models to adjust parameters like "temperature," "presence penalty," and "frequency penalty" to control the creativity, specificity, and style of the AI's output.

---

### **Level 2: Building Autonomous Voice Agents with MCP**

- **"Integrate connectors using MCP—both online and offline. Then, design system prompts to power fully autonomous voice agents."**

Level 2 is about making AI take action in the real world by connecting it to other software and services.

- **Model Context Protocol (MCP):** This is a groundbreaking technology that allows AI to use other tools, both online and on your computer. It’s the key to automating jobs. Instead of just providing information, the AI can perform tasks.
- **Online Integration:** The session demonstrated connecting an AI (Claude) to the web service **Appify** using MCP. With a single prompt, the AI could scrape an Instagram profile, analyze the top-performing content, get transcripts, and rewrite them in a new style—a process that would manually take days.
- **Offline Integration:** Using an MCP tool called **Goose**, Vaibhav showed how an AI can be given access to a folder on your local computer to analyze files and perform tasks like identifying files to delete to free up space.
- **Autonomous Voice Agents:** By integrating with tools like **WAPI**, MCP can be used to create AI agents that make phone calls on your behalf. The AI can understand the context of the conversation, deliver a message, and even respond to questions from the person on the other end of the line.

---

### **Level 3: Mastering Diffusion Models for Creative Content**

- **"Learn about Diffusion Models. Build your own AI Clone, Create Images & Videos, Ads, Branding Material, Movies"**

This level focuses on the creative domain, moving beyond text to generate multimedia content.

- **Diffusion Models:** These are the underlying technology behind AI image and video generators. Understanding how they work is key to creating high-quality visual content.
- **AI Clone Creation:** Level 3 is where you learn to create a complete digital replica of yourself. The session revealed that Vaibhav's entire Instagram presence—including his image, voice, and the video scripts—is completely AI-generated. This AI clone can create content, engage with an audience, and even participate in brand deals, all with minimal human intervention.
- **Automated Content Creation:** By mastering these tools, you can create a fully automated content engine that produces stunning images, videos, ads, and other branding materials, enabling rapid growth and scalability.

---

### **Level 4: Building Agentic Workflows for Process Optimization**

- **"Build complex automations & agentic workflows for process optimization. Get hands-on with AI Agents"**

At this level, you combine all the previous skills to build sophisticated AI agents that can handle complex, multi-step tasks.

- **AI Agents:** These are not just tools; they are autonomous systems designed to achieve a specific goal.
- **The "Jerry" Agent:** Vaibhav demonstrated an AI agent he built named "Jerry."
    - **As a Web Researcher:** Jerry was tasked with visiting the Y Combinator website, analyzing all the companies in a specific batch, identifying those relevant to consumer tech, and compiling the research into a Google Sheet—all completely on its own.
    - **As an Executive Assistant:** The same agent, integrated into Slack, could manage calendars, book meetings, and even attend meetings on his behalf using a connection to **[Fireflies.ai](http://Fireflies.ai)** to take notes and provide summaries.
- **Agentic Browser:** Tools like **Comet by Perplexity** are turning the web browser itself into an AI agent. You can give it tasks like "check my unread LinkedIn messages and summarize the important ones" or "log into my newsletter dashboard and tell me the open rate of my last email," and it will perform these actions for you.

---

### **Level 5: Building AI Products Without Code**

- **"Build a real-world AI product without writing a single line of code!"**

This is the pinnacle of the AI Generalist's journey: moving from using tools to building them.

- **Vibe Coding:** This is a new paradigm of software development where you can build fully functional applications by describing what you want in natural language.
- **Solve Real Problems:** The session showcased an "AI Creative Strategist" tool that Vaibhav built for his team. This tool solves the problem of writing complex prompts for image generation. The team simply inputs their creative idea in plain text, and the tool automatically generates multiple sophisticated prompts and even opens them in new tabs in ChatGPT, ready to be run. This saved the company lakhs in salary for a graphic designer.

By progressing through these five levels, an individual can transform from a user of AI into a creator and a strategic problem solver, capable of building immense value in any field they choose.

![Screenshot 2025-08-24 at 11.08.32 AM.png](attachment:9a2724e3-4acd-4886-9536-ab524aa42d6d:Screenshot_2025-08-24_at_11.08.32_AM.png)

### **List of Tools Used In The Session :**

|**AI Tool**|**Official Website Link**|**Notes**|
|---|---|---|
|**ChatGPT**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fchat.openai.com)**[https://chat.openai.com](https://chat.openai.com)**|Core AI chat and content generation platform by OpenAI.|
|**Gemini**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fgemini.google.com)**[https://gemini.google.com](https://gemini.google.com)**|Google's AI model and tool, highlighted for its free app-building feature (Gems).|
|**OpenAI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenai.com)**[https://openai.com](https://openai.com)**|The parent research and deployment company for ChatGPT and DALL-E.|
|**DALL-E**|[**](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenai.com%2Fdall-e-3)[https://openai.com/dall-e-3**](https://openai.com/dall-e-3**)|OpenAI's AI model for generating images from text descriptions.|
|**[Emily.ai](http://Emily.ai)**|[https://link.outskill.com/emily-outskill](https://link.outskill.com/emily-outskill)|The tool mentioned for summarizing videos could not be definitively located. A popular alternative with similar functionality is **Eightify** ([](https://www.google.com/url?sa=E&q=https%3A%2F%2Feightify.app)**[https://eightify.app](https://eightify.app)**).|
|**[Fireflies.ai](http://Fireflies.ai)**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Ffireflies.ai)**[https://fireflies.ai](https://fireflies.ai)**|An AI assistant for recording, transcribing, and taking notes in meetings.|
|**Perplexity AI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.perplexity.ai)**[https://www.perplexity.ai](https://www.perplexity.ai)**|An AI-powered search engine and research tool that provides sources for its answers.|
|**WriteSonic**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwritesonic.com)**[https://writesonic.com](https://writesonic.com)**|An AI writing assistant for creating SEO-friendly content for various formats.|
|**Numerous AI**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fnumerous.ai)**[https://numerous.ai](https://numerous.ai)**|A tool that integrates AI capabilities directly into Excel and Google Sheets for data analysis.|
|**Social Sonic**|[**](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwritesonic.com%2Fsocial-sonic-ai)[https://writesonic.com/social-sonic-ai**](https://writesonic.com/social-sonic-ai**)|An AI tool for generating content ideas and posts for social media, noted as being part of the Writesonic suite.|
|**VAPI**|[https://link.outskill.com/vapi-outskill](https://link.outskill.com/vapi-outskill)|A platform for developing and deploying AI-powered voice agents.|
|**Chronicle HQ**|[https://link.outskill.com/chronicle-outskill](https://link.outskill.com/chronicle-outskill)|An AI-powered tool specifically designed for creating professional presentations.|
|**Open Router**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fopenrouter.ai)**[https://openrouter.ai](https://openrouter.ai)**|A platform that allows access to a diverse range of AI models from various developers in one place.|
|**Bolt AI**|[https://boltai.com/](https://boltai.com/)|A user interface that connects with platforms like Open Router to utilize different open-source AI models.|
|**Olama**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Follama.com)**[https://ollama.com](https://ollama.com)**|A tool that enables users to run powerful open-source AI models locally on their own machines.|
|**Bolt**|[https://link.outskill.com/bolt-outskill](https://link.outskill.com/bolt-outskill)|An AI-powered website and landing page builder that works without requiring code.|
|**V0**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fv0.dev)**[https://v0.dev](https://v0.dev)**|A tool by Vercel that generates user interface (UI) components from text prompts.|
|**Appify (Apify)**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fapify.com)**[https://apify.com](https://apify.com)**|The transcript mentions "Appify," which is likely a reference to Apify, a well-known web scraping and automation platform.|
|**Goose**|[https://block.github.io/goose/](https://block.github.io/goose/)|Described as an open-source MCP tool for local file management. An official public link could not be located, as this may be an internal or less-known tool.|
|**Happy Scribe**|[](https://www.google.com/url?sa=E&q=https%3A%2F%2Fwww.happyscribe.com)**[https://www.happyscribe.com](https://www.happyscribe.com)**|An online service for automatically transcribing audio and video files into text.|

### **The LinkedIn Post Generator Prompt**

# **Role:**

You are a creative and dynamic LinkedIn content writer for Outskill, specializing in crafting viral posts that are engaging, personal, and highly shareable.

# **Objective:**

Your goal is to write a viral LinkedIn post that encourages engagement and promotes the 2-day Generative AI mastermind by Outskill. The post should reflect the learner’s excitement, commitment, and accountability while encouraging others to join the waitlist.

# **Context:**

A learner has shared:

1. **Why they are excited to join the 2-day Generative AI mastermind.**
2. **What they currently do professionally.**

Your task is to use this information to create a viral LinkedIn post with an attention-grabbing hook, storytelling, and industry-specific personalization. The learner should be excited to spend 16+ hours over 2 days mastering AI tools and techniques, and be ready to share their learnings once the mastermind is over.

# **Instructions:**

## **Instruction 1: Hook Creation**

- Write a **strong, attention-grabbing hook** that highlights their excitement about dedicating 2 full days (16+ hours) over the weekend to mastering AI, and make it public for accountability.
- Example:
    - **"I’m dedicating my entire weekend — 16+ hours — to mastering AI tools, and I’m putting it out here so you can hold me accountable! 🎯"**
- Make sure you come up with something original every time.
- Try to get @GrowthSchool tagged on the hook and, if possible, @vaibhavsisinty.

## **Instruction 2: Storytelling and Personalization**

- Ensure each sentence has a **line break** to maintain proper spacing when copied to LinkedIn.
- Expand on the learner’s **personal journey** and their reasons for joining the mastermind.
- Mention relevant sessions like:
    - **Session 1**: Introduction to Generative AI & LLMs—understanding transformers and prompt engineering.
    - **Session 2**: Diffusion models and their future potential.
    - **Session 3**: Image and video generation using MidJourney.
    - **Session 4**: Custom GPT creation and Assistant API.
    - **Session 5**: AI automations with no-code tools like Make.
- Include a section for the learner to share what they are excited about:
    - **"Here’s what I’m most excited about 👇"**
        - 🤖 _Understanding how LLMs like ChatGPT work and applying them in my daily work._
        - 🎨 _Building hyper-realistic images & videos—perfect for [industry-specific examples]._
        - 🧠 _Creating a custom GPT that can automate [industry task] or solve [specific problem]._

### **Instruction 3: Post-Session Accountability**

- After the 2-day event, they’ll share what they learned:
    - **"Once these 2 intense days are over, I’ll be back to share everything I’ve learned. Feel free to keep me accountable!"**
- Highlight tasks they’ll complete:
    - **TASK 1.1**: Creating their own prompt library.
    - **TASK 1.2**: Building an app using [Claude.ai](http://Claude.ai).
    - **TASK 2**: Creating a seamless video using AI-generated images and voiceovers.
    - **TASK 3**: Developing a custom GPT for a specific use case.

### **Instruction 4: Call to Action (CTA)**

- Close with a **direct CTA**:
    
    - **"Btw, want to join the next 2-day Generative AI Mastermind?"**
        
        **Join the waitlist:** [https://www.outskill.com/mastermind-referral](https://www.outskill.com/mastermind-referral)
        
- Encourage urgency with a reminder of limited seats.
    

### **Notes:**

1. Make sure there is a tagging of @Outskill and @Vaibhav Sisinty to maximize visibility in the beginning.
2. Ensure each sentence is on a new line and add 3 line breaks or white spaces after every line to maintain proper spacing when copying to LinkedIn.
3. Add the following hashtags at the end of the post: **#Outskill #AImastermind**
4. For text bolding, use **this format** (e.g., **Bold text**) in the output.
5. Always give the output in a code editor in plain text so the formatting doesn’t break and it’s easy to copy to LinkedIn.

References