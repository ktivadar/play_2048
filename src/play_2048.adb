with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;
with Sf.Graphics.Font;
with Sf.Graphics.Text;
with Sf.Graphics.Image;

with Sf.Window.VideoMode;
with Sf.Window.Event;
with Sf.Window.Keyboard;
with Sf.Window.Window;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Calendar.Formatting;

with Storage;
with Game;

procedure Play_2048 is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;
   use Sf;

   type t_Keystroke is (Up, Down, Right, Left,
                        Quit, Restart, Fullscreen_On_Off, Switch_Theme, Undo,
                        Nothing, Invalid);

   subtype t_Direction_Key is t_Keystroke range Up .. Left;

   function Get_Keystroke (Key_Code : Keyboard.sfKeyCode) return t_Keystroke is
     (case Key_Code is
         when Keyboard.sfKeyQ => Quit,
         when Keyboard.sfKeyR => Restart,
         when Keyboard.sfKeyF11 => Fullscreen_On_Off,
         when Keyboard.sfKeyTab => Switch_Theme,
         when Keyboard.sfKeyW | Keyboard.sfKeyLeft => Left,
         when Keyboard.sfKeyA | Keyboard.sfKeyUp => Up,
         when Keyboard.sfKeyS | Keyboard.sfKeyDown => Down,
         when Keyboard.sfKeyD | Keyboard.sfKeyRight => Right,
         when Keyboard.sfKeyU => Undo,
         -- Modifier keys should not trigger anything.
         when Keyboard.sfKeyLControl .. Keyboard.sfKeyRAlt => Nothing,
         when others => Invalid);

   type t_Theme is range 1 .. 9;

   Not_Supported_Size : exception;

   function Adjusted_Video_Mode return VideoMode.sfVideoMode is
     (case Game.Board_Length is
         when Game.Default_Length - 1 => ( 640, 480, 32),
         when Game.Default_Length     => ( 800, 600, 32),
         when Game.Default_Length + 1 => (1024, 768, 32),
         when others =>
            raise Not_Supported_Size with "Board size is too low or too high");

   State       : Game.t_Board_State;
   New_State   : Game.t_Board_State;
   Old_State   : Game.t_Board_State;
   Best_Score  : Natural := 0;
   Best_Time   : Duration := Ada.Calendar.Day_Duration'Last - 1.0;
   Last_Elapsed_Time : Duration := 0.0;
   Video_Mode  : constant VideoMode.sfVideoMode := Adjusted_Video_Mode;
   App_Win     : SfRenderWindow_Ptr;
   Icon        : sfImage_Ptr;
   App_Event   : Event.sfEvent;
   Has_Changed : Boolean := True;
   Tiles       : sfTexture_Ptr;
   Tile_Size   : constant := 128;
   Board_Size  : constant Positive := Tile_Size * Game.t_Board'Length;
   Margin      : constant Positive := (Positive (Video_Mode.Height) - Board_Size) / 2;
   Pane_Center : constant Positive := Positive (Video_Mode.Width) -
     (Positive (Video_Mode.Width) - Board_Size - Margin) / 2;
   Tile_Sprite : constant sfSprite_Ptr := Sprite.create;
   Game_Sprite : constant sfSprite_Ptr := Sprite.create;
   Game_Image  : sfTexture_Ptr;
   Game_Font   : sfFont_Ptr;
   Score_Text  : constant sfText_Ptr := Text.create;
   Game_Text   : constant sfText_Ptr := Text.create;
   Text_UI     : Boolean := False;
   Help        : constant String :=
     "Arrows: move" & ASCII.LF &
     "U: undo" & ASCII.LF &
     "R: restart game" & ASCII.LF &
     "Q: quit game" & ASCII.LF &
     "F11: fullscreen" & ASCII.LF &
     "Tab: next theme";

   Fullscreen : Boolean := Storage.Fullscreen_Mode;
   Theme      : t_Theme := t_theme (Storage.Theme);
   First_Time : Boolean := True;

   function Create_Window return SfRenderWindow_Ptr is
      (RenderWindow.create
        (mode  => Video_Mode,
         title => "2048 Game!",
         style => (if Fullscreen then Sf.Window.Window.sfFullscreen
                   else Sf.Window.Window.sfDefaultStyle)));


   procedure Draw_Scoreboard is
      Elapsed_Time : constant string := Ada.Calendar.Formatting.Image
        (Elapsed_Time => Game.Elapsed_Time (State));
      Best_Time_Image : constant String := Ada.Calendar.Formatting.Image
        (Elapsed_Time => Best_Time);
   begin

      Text.setString (Score_Text, "Score" & ASCII.LF & State.Score'Image & ASCII.LF & ASCII.LF &
                        "Best score" & ASCII.LF & Best_Score'Image & ASCII.LF & ASCII.LF &
                        "Time" & ASCII.LF & " " & Elapsed_Time & ASCII.LF & ASCII.LF &
                        "Best time" & ASCII.LF & " " & Best_Time_Image);
      Text.setPosition (Score_Text,
                        (x => Float (Pane_Center) - Text.getLocalBounds (Score_Text).width / 2.0,
                         y => Float (Margin)));
      RenderWindow.drawText (App_Win, Score_Text);

   end Draw_Scoreboard;

   procedure Display_Text (Message : String) is
      Board_Center : constant Float := Float (Margin + Board_Size / 2);

   begin
      if Text_UI then
         Put_Line (Message);
      end if;

      Text.setString (Game_Text, Message);
      Text.setPosition (Game_Text,
                        (x => Board_Center - Text.getLocalBounds (Game_Text).width / 2.0,
                         y => Board_Center - Text.getLocalBounds (Game_Text).height / 2.0));
      RenderWindow.drawText (App_Win, Game_Text);

   end Display_Text;

   -- ----- Displaying the board
   procedure Display_Board (Message : String := "") is
      Horizontal_Rule : constant String := "+----+----+----+----+";
      function Center (Value : in String) return String is
         Target : String (1 .. 4);
      begin
         Ada.Strings.Fixed.Move
           (Source => Value, Target => Target, Justify => Ada.Strings.Center);
         return Target;
      end Center;

      Board : Game.t_Board renames State.Board;
      Elapsed_Time : constant string := Ada.Calendar.Formatting.Image
        (Elapsed_Time => Game.Elapsed_Time (State));
      Best_Time_Image : constant String := Ada.Calendar.Formatting.Image
        (Elapsed_Time => Best_Time);
   begin
      if Text_UI then
         Put_Line (Horizontal_Rule);
         for Row of Board loop
            for Cell of Row loop
               Put('|' & (if Cell = 0 then "    " else Center(Cell'Img)));
            end loop;
            Put_Line("|");
            Put_Line (Horizontal_Rule);
         end loop;
         Put_Line("Score =" & State.Score'Image &
                    "  Time = " & Elapsed_Time &
                    "  Best Score =" & Best_Score'Image &
                    "  Best Time = " & Best_Time_Image);
      end if;

      RenderWindow.clear(App_Win, sfWhite);

      for i in Board'range loop
         for j in Board(i)'range loop
            declare
               Cell : Natural renames Board(i)(j);
               Sprite_Offset : constant Natural := Natural (if Cell = 0 then 0.0
                                                            else Log (X    => Float (Cell),
                                                                      Base => 2.0));
            begin
               Sprite.setTextureRect(Tile_Sprite,
                                     (Sprite_Offset * Tile_Size, 0, Tile_Size, Tile_Size));

               Sprite.setPosition(Tile_Sprite,
                                  (x => Float(Margin + (j - 1) * Tile_Size),
                                   y => Float(Margin + (i - 1) * Tile_Size)));

               RenderWindow.drawSprite(App_Win, Tile_Sprite);
            end;
         end loop;
      end loop;

      Draw_Scoreboard;

      if Game.Board_Length >= Game.Default_Length then

         Sprite.setPosition(Game_Sprite,
                            (x => Float (Pane_Center -
                                           Positive (Image.getSize (Icon).x) / 2),
                             y => Float (Positive (Video_Mode.Height) - Margin -
                                           Positive (Image.getSize (Icon).y))));
         RenderWindow.drawSprite(App_Win, Game_Sprite);
      end if;

      if Message /= "" then
         Display_Text(Message);
      end if;

      RenderWindow.display(App_Win);

      Last_Elapsed_Time := Game.Elapsed_Time (New_State);

   end Display_Board;

   procedure Set_Text_Style
     (The_Text : sfText_Ptr) is
   begin
      Text.setFont (The_Text, Game_Font);
      Text.setOutlineColor (The_Text, (R => 32, G => 32, B => 32, A => 255));
      Text.setFillColor (The_Text, (R => 196, G => 160, B => 0, A => 255));
      Text.setOutlineThickness (The_Text, 1.0);
   end Set_Text_Style;

   function Theme_Path (Theme_Id : t_theme) return String is
     (-- Use the APPDIR env var if defined. In this way we allow
      -- running from an AppImage and still find the resource files.
      --
      (if Ada.Environment_Variables.Exists ("APPDIR") then
          Ada.Environment_Variables.Value ("APPDIR") & "/"
       else "") &
        "themes/" & Ada.Strings.Fixed.Trim (Theme_Id'Image,
                                            Ada.Strings.Left) & "/");

   function Next_Theme return t_Theme is
     (if Theme + 1 > t_Theme'Last or else not Ada.Directories.Exists (Theme_Path (Theme + 1))
      then t_Theme'First
      else Theme + 1);

   procedure Load_Theme is
      Path : constant String := Theme_Path (Theme);
   begin

      if Tiles /= null then
         Texture.destroy (Tiles);
      end if;
      if Game_Font /= null then
         Font.destroy (Game_Font);
      end if;
      if Icon /= null then
         Image.destroy (Icon);
      end if;
      if Game_Image /= null then
         Texture.destroy (Game_Image);
      end if;

      Tiles := Texture.createFromFile (Path & "tiles.png");

      pragma Assert (Texture.getSize (Tiles).y = Tile_Size);

      Game_Font := Font.createFromFile(Path & "font.ttf");
      Icon := Image.createFromFile (Path & "icon.png");
      Game_Image := Texture.createFromImage (Icon);

      pragma Assert (Game_Font /= null and Icon /= null and Game_Image /= null);

      Sprite.setTexture (Tile_Sprite, Tiles);
      Sprite.setTexture (Game_Sprite, Game_Image);

      Set_Text_Style (Score_Text);
      Text.setLineSpacing (Score_Text, 0.85);
      Set_Text_Style (Game_Text);

      RenderWindow.setIcon
        (renderWindow => App_Win,
         width => Image.getSize (Icon).x,
         height => Image.getSize (Icon).y,
         pixels => Image.getPixelsPtr (Icon));

   end Load_Theme;

   function To_Direction (Keystroke : t_Direction_Key) return Game.t_Direction is
     (case Keystroke is
         when Left    => Game.Left,
         when Right   => Game.Right,
         when Up      => Game.Up,
         when Down    => Game.Down);

begin

   Text_UI := Ada.Command_Line.Argument_Count >= 1 and then
     Ada.Command_Line.Argument (1) = "-text";

   App_Win := Create_Window;

   renderWindow.setFramerateLimit (App_Win, 30);

   Load_Theme;

   if Game.Board_Length >= Game.Default_Length then
      Text.setCharacterSize (Game_Text, Text.getCharacterSize (Game_Text) * 2);
   end if;

   Best_Score := Storage.Best_Score;
   Best_Time := Storage.Best_Time;

   Main_Loop:
   loop

      if First_Time then
         Storage.Restore_Game (State);
         Old_State := State;
         First_Time := False;
      else
         Game.Restart_Game (State);
      end if;

      Game_Loop:
      loop

         if Has_Changed then
            Display_Board;
         end if;

         if RenderWindow.pollEvent (App_Win, event => App_Event) /= sfTrue then
            Has_Changed := False;
         else
            Has_Changed := True;
            case App_Event.eventType is
               when Event.sfEvtClosed =>

                  RenderWindow.Close (App_Win);
                  exit Main_Loop;

               when Event.sfEvtResized =>

                  Display_Board;
                  Has_Changed := False;

               when Event.sfEvtKeyPressed =>

                  case Get_Keystroke (Key_Code => App_Event.key.code) is
                     when Restart =>
                        exit Game_Loop;
                     when Quit =>
                        exit Main_Loop;
                     when t_Direction_Key =>

                        Game.Move
                          (Direction =>
                             To_Direction (Get_Keystroke (Key_Code => App_Event.key.code)),
                           State => State,
                           New_State => New_State);

                        if New_State.Score > Best_Score then
                           Best_Score := New_State.Score;
                        end if;

                     when Fullscreen_On_Off =>

                        Fullscreen := not Fullscreen;
                        RenderWindow.destroy (App_Win);
                        App_Win := Create_Window;

                        Display_Board;
                        Has_Changed := False;

                     when Switch_Theme =>

                        Theme := Next_Theme;

                        Load_Theme;

                        Display_Board (Message => "Theme" & Theme'Image);
                        Has_Changed := False;

                     when Undo =>

                        State := Old_State;
                        Display_Board (Message => "Undone!");
                        Has_Changed := False;
                     when Nothing =>

                        Has_Changed := False;

                     when Invalid =>
                        Display_Board (Message => Help);
                        Has_Changed := False;

                  end case;

               when others =>
                  Has_Changed := False;
            end case;

         end if;

         if not Has_Changed then

            if Game.Elapsed_Time (New_State) - Last_Elapsed_Time > 1.0 then
               --  Draw_Scoreboard;
               --  RenderWindow.display(App_Win);
               Display_Board;
               --Last_Elapsed_Time := Game.Elapsed_Time (New_State);
            end if;

         elsif Game."=" (New_State.Board, State.Board) then
            Display_Board (Message => "Invalid move...");
            Has_Changed := False;
         elsif Game.Has_Won (New_State.Board) then
            Old_State := State;
            State := New_State;
            Best_Time := Duration'Min (Game.Elapsed_Time (New_State),
                                       Best_Time);
            Display_Board (Message => "You win!");
            Has_Changed := False;
            exit Game_Loop;
         else
            Old_State := State;
            State := New_State;
            Game.Add_Block (State); -- OK since the board has changed
            if Game.Has_Lost (State) then
               Display_Board (Message => "You lose!");
               Has_Changed := False;
               exit Game_Loop;
            end if;
         end if;
      end loop Game_Loop;
   end loop Main_Loop;

   Storage.Save_State
     (Best_Score => Best_Score,
      Best_Time => Best_Time,
      Fullscreen_Mode => Fullscreen,
      Theme => Natural (Theme),
      Game_State => State);

   RenderWindow.destroy (App_Win);

exception
   when others =>
      RenderWindow.destroy (App_Win);
      raise;
end Play_2048;
