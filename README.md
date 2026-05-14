# RV32IMC Processor Core Vivado Setup

This repository contains the processor files from the [CIDR RV32IMC Project](https://gitlab.eee.upd.edu.ph/cidr-p3-public/pipelined-RV32IMC/-/tree/master?ref_type=heads), with modifications from Hora et al.

## Files to Download

Download the following folders/files before creating the Vivado project:

1. [second_import_files](https://drive.google.com/drive/folders/1OLKL3d8LRpCeD8sCe7np8FxyHxcBp54E?usp=drive_link)
2. [NEW second_import_files](https://drive.google.com/drive/folders/1VVjZdFEsaMmFBCsvrEgEZ5Bqd3OeqhHY?usp=sharing)
3. [MIG_7](https://drive.google.com/drive/folders/1m5bgVZMtVzj3Vllg9JPMsSTLAW96qnyu?usp=sharing)  
   Place this in the same folder as `second_import_files`.
4. [Nexys Video board files](https://drive.google.com/drive/folders/1OLKL3d8LRpCeD8sCe7np8FxyHxcBp54E?usp=drive_link)  
   Copy these to:

   ```text
   D:\Xilinx\Vivado\2024.1\data\boards\board_files
   ```

5. [Datamem and Instmem COE files](https://drive.google.com/drive/folders/1OLKL3d8LRpCeD8sCe7np8FxyHxcBp54E?usp=sharing)
6. [MCS Folder](https://drive.google.com/drive/folders/1jLJ0glUKPrnkScBCat9Iahh-sUfTC03I?usp=sharing)

## Importing the Processor Core

1. Open Vivado.
2. Create a new project.
3. Click **Next** until you reach the **Boards** tab.
4. Select **Nexys Video**.
5. Open `import_project.tcl` in Notepad or another text editor.
6. Change the source directory to the location of your downloaded `GitHub CoE 199 repo` folder.
7. In Vivado, go to **Tools > Run Tcl Script**, then select `import_project.tcl`.

   Checkpoint: after running the script, there should be around **47 files** in **Design Sources**.

   > Note: The folder contains three new Verilog files for QSPI. The Block Design Tcl already includes the DMA controller and CSR modules, so make sure those modules are also present in your Design Sources. If `second_import_files` does not include the DMA controller and CSR Verilog files, add them manually alongside the other processor files.

8. In the **Sources** pane, right-click the constraint folder:

   ```text
   Constraints > a7_200t
   ```

   Then select **Make Active**.

9. Open `CoE_199_Full_System.tcl`.
10. Search for `datamem_run` and `instmem_run`.
11. Replace the paths with the local paths to your own `datamem_run.coe` and `instmem_run.coe` files.
12. In Vivado, go to **Tools > Run Tcl Script**, then run:

   ```text
   CoE_199_Full_System.tcl
   ```

   This should build the block design. As long as all required modules are present in the processor folder inside `second_import_files`, the block design should build successfully.

## Generating the Divider IPs

Vivado requires two Divider Generator IPs:

- `div_gen_signed`
- `div_gen_unsigned`

Follow these steps for each Divider Generator IP:

1. In the left **Project Manager** panel, click **IP Catalog**.
2. Search for **Divider Generator**.
3. Open it and click **Customize IP**.
4. Name the IP either:

   ```text
   div_gen_signed
   ```

   or:

   ```text
   div_gen_unsigned
   ```

5. Apply the settings shown in the reference images from the original setup guide.
6. Generate the output products for each IP.

## Generating the Bitstream

1. Make sure all modified Verilog modules are saved.
2. If you made changes to IPs, click **Report IP Status**.
3. Select **Upgrade Selected** if Vivado reports outdated IPs.
4. Generate output products for the upgraded IPs. Select **Global**.
5. After all IPs are updated, right-click the block design and select **Validate Design**.
6. Save the block design with **Ctrl + S**.
7. In the **Sources** pane, click **IP Sources**.
8. Right-click `uart_bd`.
9. Select **Reset Output Products**.
10. Right-click `uart_bd` again.
11. Select **Create HDL Wrapper**.
12. Ignore warnings if they only say that some pins are not connected.
13. Right-click `uart_bd` again.
14. Select **Generate Output Products**.
15. Choose **Global**.
16. Click **Generate Bitstream**.

## Programming and Running on the Board

1. After generating the bitstream, click **Open Hardware Manager** in the Flow Navigator.
2. Click **Auto Connect** when searching for a target.
3. The Nexys Video board should appear.
4. When Vivado shows **Add Configuration Memory Device**, click it.
5. In the search bar, search for:

   ```text
   s25fl256sxxxxxx0-spi-x1_x2_x4
   ```

6. Select the device.
7. When Vivado asks whether you want to program the memory configuration device now, click **OK**.
8. In the programming window, load the `.mcs` file by clicking the ellipsis button.
9. Make sure the required programming options are checked.
10. Click **Apply**, then click **OK**.
11. Vivado should print blue command messages in the Tcl console after clicking **Apply** and **OK**.
12. If there are no errors, Vivado will proceed through the programming and verification steps.

## UART / PuTTY Setup

Open the serial terminal before or during configuration memory programming.

After setting up PuTTY or another UART terminal, return to Vivado and continue with the next step.

## Programming the FPGA Device

1. In the green task area at the top of Vivado, click **Program Device**.
2. Vivado should show the generated bitstream and the `.ltx` debug ILA file.
3. Make sure the selected bitstream is the correct one.
4. Click **Program**.
5. At first, nothing may print on the serial terminal. This is expected while the QSPI bootloader is active.
6. After around 10 to 15 seconds, UART output should appear, depending on the program currently loaded.

## Remarks

I am not completely sure whether this setup will always work without manually importing the `MIG_7` IP into the block design instead of relying only on the BD Tcl script. If Vivado reports errors related to `MIG_7`, try importing the IP manually and rerunning the block design generation steps.
