from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
)


OUTPUT = "deliverables/CHIP8_Minor_Project_Proposal.pdf"


class ProposalDocTemplate(BaseDocTemplate):
    def beforeDocument(self):
        self.canv.setTitle(
            "Design and Implementation of a CHIP-8 System on FPGA with VGA Display"
        )
        self.canv.setAuthor("Minor Project Proposal")


styles = getSampleStyleSheet()
body = ParagraphStyle(
    "Body",
    parent=styles["Normal"],
    fontName="Times-Roman",
    fontSize=11.5,
    leading=14.1,
    alignment=TA_JUSTIFY,
    spaceAfter=10,
)
heading = ParagraphStyle(
    "Heading",
    parent=body,
    fontName="Times-Bold",
    alignment=TA_LEFT,
    spaceBefore=2,
    spaceAfter=7,
)
topic = ParagraphStyle(
    "Topic",
    parent=heading,
    fontSize=12,
    leading=14,
    spaceAfter=17,
)
cover_institute = ParagraphStyle(
    "CoverInstitute",
    parent=body,
    fontName="Times-Bold",
    fontSize=15.5,
    leading=19,
    alignment=TA_CENTER,
    spaceAfter=7,
)
cover_label = ParagraphStyle(
    "CoverLabel", parent=body, fontSize=15, leading=18, alignment=TA_CENTER
)
cover_title = ParagraphStyle(
    "CoverTitle",
    parent=body,
    fontName="Times-Bold",
    fontSize=17,
    leading=20,
    alignment=TA_CENTER,
)
cover_detail = ParagraphStyle(
    "CoverDetail", parent=body, fontSize=12, leading=15, alignment=TA_LEFT
)
module = ParagraphStyle("Module", parent=body, spaceAfter=7)
label = ParagraphStyle(
    "Label", parent=body, fontName="Times-Bold", alignment=TA_LEFT, spaceAfter=6
)


def bullets(items, bullet_type="bullet", start=None, bottom=8):
    flow_items = [
        ListItem(Paragraph(text, body), leftIndent=0) for text in items
    ]
    kwargs = dict(
        bulletType=bullet_type,
        leftIndent=22,
        rightIndent=0,
        bulletFontName="Times-Roman",
        bulletFontSize=11,
        bulletOffsetY=1,
        spaceAfter=bottom,
    )
    if start is not None:
        kwargs["start"] = start
    return ListFlowable(flow_items, **kwargs)


doc = ProposalDocTemplate(
    OUTPUT,
    pagesize=letter,
    leftMargin=0.78 * inch,
    rightMargin=0.78 * inch,
    topMargin=0.72 * inch,
    bottomMargin=0.68 * inch,
)
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")
doc.addPageTemplates(PageTemplate(id="letter", frames=[frame]))

story = [
    Spacer(1, 0.02 * inch),
    Paragraph("MAHARAJA AGRASEN INSTITUTE OF TECHNOLOGY", cover_institute),
    Paragraph("Minor Project Proposal :", cover_label),
    Paragraph(
        "Design and Implementation of a CHIP-8 System on FPGA<br/>with VGA Display",
        cover_title,
    ),
    Spacer(1, 3.52 * inch),
    Paragraph("Submitted to : ______________________________", cover_detail),
    Spacer(1, 7),
    Paragraph(
        "BY: ____________________ [_______________] &amp; "
        "____________________ [_______________]",
        cover_detail,
    ),
    Spacer(1, 7),
    Paragraph("SECTION: __________", cover_detail),
    PageBreak(),
    Paragraph(
        "Topic - Design and Implementation of a CHIP-8 System on FPGA with VGA Display",
        topic,
    ),
    Paragraph("Abstract", heading),
    Paragraph(
        "This project proposes the design and implementation of a CHIP-8 virtual machine "
        "entirely in hardware using Field Programmable Gate Array (FPGA) technology. The "
        "system will execute CHIP-8 game ROMs through a Verilog-based processor, store "
        "programs and data in 4 KB memory, render the 64×32 monochrome framebuffer on a "
        "VGA monitor, and accept user input from a PS/2 keyboard. Delay and sound timers, "
        "configurable instruction pacing, and buzzer output will reproduce the essential "
        "behavior of the original platform. The work follows a complete digital design flow "
        "comprising RTL development, functional simulation, synthesis, FPGA programming, "
        "and hardware validation on the DE0-Nano development board.",
        body,
    ),
    Paragraph("1. Introduction", heading),
    Paragraph(
        "FPGA devices provide a flexible platform for studying processor architecture, "
        "memory organization, video timing, peripheral interfaces, and real-time digital "
        "control. CHIP-8 is a compact interpreted system with two-byte instructions, sixteen "
        "general-purpose registers, a 4 KB address space, a 16-level stack, timers, keypad "
        "input, and sprite-based graphics. Its small but complete architecture makes it well "
        "suited to an educational hardware implementation. This project focuses on building "
        "a modular CHIP-8 system in Verilog and displaying its output through standard VGA, "
        "thereby connecting digital design concepts with an interactive and visually "
        "verifiable application.",
        body,
    ),
    Paragraph("2. Problem Statement", heading),
    Paragraph(
        "Most CHIP-8 emulators run as software on a general-purpose computer, where "
        "instruction decoding, graphics, and input handling are performed sequentially by an "
        "existing processor and operating system. The problem addressed in this project is "
        "to realize the CHIP-8 execution environment directly as synchronous FPGA hardware. "
        "The design must correctly coordinate opcode fetch and execution, memory access, "
        "sprite drawing and collision detection, 60 Hz timers, keyboard input, VGA timing, "
        "and audio output while operating reliably within the timing and resource constraints "
        "of the target board.",
        body,
    ),
    Paragraph("3. Objectives", heading),
    bullets(
        [
            "To design and implement a CHIP-8 processor in synthesizable Verilog",
            "To support the standard CHIP-8 instruction set, registers, stack, memory, and timers",
        ],
        bottom=0,
    ),
    PageBreak(),
    bullets(
        [
            "To generate VGA output from a 64×32 framebuffer scaled for a 640×480 display",
            "To interface the sixteen-key CHIP-8 keypad through a PS/2 keyboard",
            "To provide sound-timer output through a passive buzzer",
            "To simulate, synthesize, program, and validate the complete system on FPGA hardware",
        ]
    ),
    Paragraph("4. Proposed System", heading),
    Paragraph(
        "The proposed CHIP-8 system will consist of the following major modules:", body
    ),
    Paragraph(
        "<b>CHIP-8 Processing Unit –</b> Fetches and decodes two-byte opcodes and controls "
        "sixteen 8-bit registers, the index register, program counter, stack, delay timer, "
        "sound timer, arithmetic operations, branching, and sprite instructions through an "
        "FSM-based datapath.",
        module,
    ),
    Paragraph(
        "<b>Memory Unit –</b> Provides a 4 KB address space, loads a converted CHIP-8 ROM at "
        "the standard address 0x200, and supports runtime data reads and writes.",
        module,
    ),
    Paragraph(
        "<b>Display Unit –</b> Maintains the 64×32 monochrome framebuffer, performs XOR sprite "
        "drawing and collision detection, and scales each CHIP-8 pixel to a 10×10 VGA pixel block.",
        module,
    ),
    Paragraph(
        "<b>Input and Audio Unit –</b> Receives PS/2 scan codes, maps keyboard keys to the "
        "hexadecimal CHIP-8 keypad, and drives a 1 kHz buzzer while the sound timer is active.",
        module,
    ),
    Paragraph(
        "<b>Timing and Control Unit –</b> Derives VGA pixel enables and configurable "
        "instruction-rate pulses from the 50 MHz board clock while keeping the design in a "
        "single clock domain.",
        module,
    ),
    Paragraph(
        "The modular architecture permits independent verification, simplifies debugging, "
        "and supports future extensions such as alternative ROM-loading methods or additional "
        "compatibility modes.",
        body,
    ),
    Paragraph("5. Methodology", heading),
    Paragraph("The project will follow a structured development process:", body),
    bullets(
        [
            "Study the CHIP-8 architecture and define functional and timing requirements",
            "Develop the CPU, memory, framebuffer, VGA, PS/2, timing, and audio modules in Verilog",
            "Convert CHIP-8 ROM files into hexadecimal FPGA memory initialization data",
            "Perform module-level and integrated functional simulation using testbenches",
            "Synthesize the design in Quartus Prime and program the DE0-Nano board",
            "Validate instruction execution, display, keyboard controls, timers, and buzzer using CHIP-8 programs",
        ],
        bullet_type="1",
        start="1",
        bottom=6,
    ),
    Paragraph("6. Tools and Technologies", heading),
    Paragraph("Hardware:", label),
    bullets(
        [
            "Terasic DE0-Nano FPGA Development Board (Intel Cyclone IV)",
            "VGA display and interface circuitry",
            "PS/2 keyboard and passive piezo buzzer",
        ],
        bottom=0,
    ),
    PageBreak(),
    Paragraph("Software:", label),
    bullets(
        [
            "Intel Quartus Prime FPGA Design Software",
            "Verilog HDL and HDL simulation tools",
            "Python ROM-to-hexadecimal conversion utility",
        ],
        bottom=13,
    ),
    Paragraph("7. Applications", heading),
    bullets(
        [
            "Educational demonstration of processor architecture and RTL design",
            "Practical study of finite state machines, memory systems, and hardware timing",
            "Demonstration of VGA generation, PS/2 interfacing, and real-time graphics on FPGA",
            "Foundation for retro-computing systems, soft processors, and hardware emulation projects",
        ],
        bottom=13,
    ),
    Paragraph("8. Conclusion", heading),
    Paragraph(
        "This project aims to demonstrate a complete interactive computing system implemented "
        "directly on FPGA hardware. By combining a Verilog CHIP-8 processor with memory, "
        "framebuffer graphics, VGA output, PS/2 keyboard input, timers, and buzzer control, the "
        "work provides practical experience across the complete digital system design flow. "
        "Successful implementation on the DE0-Nano will verify the feasibility of running "
        "CHIP-8 programs without a conventional software processor and will provide a compact "
        "platform for further study of computer architecture and FPGA-based system design.",
        body,
    ),
]

doc.build(story)
