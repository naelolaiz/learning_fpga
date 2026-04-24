library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.ALL;

library work;
use work.definitions.all;
use work.trigonometric.all;

entity sprite is
   generic (SCREEN_SIZE    : Size2D := (800,600);
            SPRITE_WIDTH   : integer := 7;
            SCALE          : integer := 3;
            SPRITE_CONTENT : std_logic_vector := "1001001"
                                               & "0101010"
                                               & "0011100"
                                               & "1111111"
                                               & "0011100"
                                               & "0101010"
                                               & "1001001";
            INITIAL_ROTATION         : integer := 0; -- 0 to 31
            INITIAL_ROTATION_SPEED           : RotationSpeed := ( 1, 0);
            INITIAL_POSITION         : Pos2D   := (0, 0);
            INITIAL_SPEED            : Speed2D := (0, 0, 0);
            -- Optional downward physics. When GRAVITY_ENABLED is false the
            -- GRAVITY record is ignored; when true, GRAVITY.y_increments is
            -- added to the sprite's y-velocity every GRAVITY.update_period
            -- clock ticks (see moveSprite below).
            GRAVITY_ENABLED          : boolean := false;
            GRAVITY                  : GravityAcceleration := (1, 3000000)
            );
   port( inClock : in  std_logic;
         inEnabled : in boolean;
         --inSpritePos   : Pos2D; -- center position of sprite
         inCursorPos   : Pos2D; -- position to check
         --inRotation    : in AngleType;
         inColision : in boolean; --TODO direction
         outShouldDraw : out boolean);
end;

architecture logic of sprite is
   constant SPRITE_SIZE          : Size2D := (SPRITE_WIDTH, SPRITE_CONTENT'length / SPRITE_WIDTH);
   type SPRITE_CONTENT_TYPE is array (SPRITE_SIZE.height-1 downto 0) of std_logic_vector (SPRITE_SIZE.width-1 downto 0);

   signal sSpriteContent  : SPRITE_CONTENT_TYPE;
   signal sCenterPos : Pos2D := (0,0);
   constant C_HALF_SCALED_WIDTH  : integer := SPRITE_SIZE.width * SCALE / 2;
   constant C_HALF_SCALED_HEIGHT : integer := SPRITE_SIZE.height * SCALE / 2;

--   signal sRotation : AngleType := INITIAL_ROTATION;
   signal sRotation : integer range 0 to 31 := INITIAL_ROTATION;
   signal sSpritePos : Pos2D := (INITIAL_POSITION.x,
                                  INITIAL_POSITION.y);
   signal sCurrentSpeed : Speed2D := INITIAL_SPEED;
   signal sCurrentRotationSpeed : RotationSpeed := INITIAL_ROTATION_SPEED;
   signal sShouldDraw : boolean := false;
begin

 -- TODO: remove hardcoded 31

outShouldDraw <= sShouldDraw;

   rotateSprite : process  (inClock)
      variable counterForSpriteRotationUpdate : integer := 0;
      variable indexForSpriteRotation : integer range 0 to 31 := 0;
   begin
       if rising_edge(inClock) then
          if counterForSpriteRotationUpdate = sCurrentRotationSpeed.update_period then
             counterForSpriteRotationUpdate := 0;
             if sCurrentRotationSpeed.index_inc > 0 then
                 if indexForSpriteRotation = 31 then
                    indexForSpriteRotation := 0;
                 else
                    indexForSpriteRotation := indexForSpriteRotation + sCurrentRotationSpeed.index_inc;
                 end if;
             elsif sCurrentRotationSpeed.index_inc < 0 then
                 if indexForSpriteRotation = 0 then
                    indexForSpriteRotation := 31;
                 else
                    indexForSpriteRotation := indexForSpriteRotation + sCurrentRotationSpeed.index_inc;
                 end if;
             end if;
             --sRotation <= TRIGONOMETRIC_FUNCTIONS_TABLE(indexForSpriteRotation).angle;
          else
             counterForSpriteRotationUpdate := counterForSpriteRotationUpdate + 1;
          end if;
       sRotation <= indexForSpriteRotation;
       end if;
   end process;

   -- Position + velocity update.
   --
   -- Uses a `currentSpeed` variable (not the sCurrentSpeed signal directly)
   -- so reads within the process see the latest velocity instead of the
   -- previous delta-cycle value. Gravity depends on that: the updated
   -- velocity must feed the same cycle's position step and bounce check.
   moveSprite : process (inClock, sShouldDraw, inColision, sCurrentSpeed)
      variable counterForSpritePositionUpdate : integer range 0 to INITIAL_SPEED.update_period := 0;
      variable nextPositionToTest : Pos2D := (0,0);
      variable collisionDetected : boolean := false;
      variable counterForVelocityUpdateByGravity : integer range 0 to GRAVITY.update_period := 0;
      variable currentSpeed : Speed2D := sCurrentSpeed;
   begin
      if rising_edge(inClock) then
         currentSpeed := sCurrentSpeed;

         -- Gravity: add `y_increments` to downward velocity every
         -- `update_period` clock cycles. On the board's 50 MHz vga_clk,
         -- the default period 3_000_000 fires ~17x per second.
         if GRAVITY_ENABLED then
            if counterForVelocityUpdateByGravity = GRAVITY.update_period then
               counterForVelocityUpdateByGravity := 0;
               currentSpeed.y := currentSpeed.y + GRAVITY.y_increments;
            else
               counterForVelocityUpdateByGravity := counterForVelocityUpdateByGravity + 1;
            end if;
         end if;

         if counterForSpritePositionUpdate = INITIAL_SPEED.update_period then
            counterForSpritePositionUpdate := 0;
            collisionDetected := false;
           -- check for colission with the screen
            -- TODO: implement vectors sum
            nextPositionToTest := ((sSpritePos.x + currentSpeed.x),
                                  (sSpritePos.y + currentSpeed.y));
            if  nextPositionToTest.x - C_HALF_SCALED_WIDTH <= 0
             or nextPositionToTest.x + C_HALF_SCALED_WIDTH >= SCREEN_SIZE.width then
               currentSpeed.x := currentSpeed.x * (-1);
               collisionDetected := true;
            end if;
            if  nextPositionToTest.y - C_HALF_SCALED_HEIGHT <= 0
             or nextPositionToTest.y + C_HALF_SCALED_HEIGHT >= SCREEN_SIZE.height then
               currentSpeed.y := currentSpeed.y * (-1);
               -- After a top-edge bounce with gravity enabled, the flipped
               -- y-velocity points downward; cap its magnitude so an
               -- accumulated fast fall doesn't launch the sprite at the
               -- same speed upward on the next bounce cycle.
               if GRAVITY_ENABLED and currentSpeed.y > 1 then
                  currentSpeed.y := 1;
               end if;
               collisionDetected := true;
            end if;
            sSpritePos <= ((sSpritePos.x + currentSpeed.x),
                           (sSpritePos.y + currentSpeed.y));
            if collisionDetected or (inColision and sShouldDraw) then
               sCurrentRotationSpeed.index_inc <= sCurrentRotationSpeed.index_inc * (-1);
            end if;
            if (inColision and sShouldDraw) then
               currentSpeed.x := currentSpeed.x * (-1);
               currentSpeed.y := currentSpeed.y * (-1);
            end if;
         else
            counterForSpritePositionUpdate := counterForSpritePositionUpdate + 1;
         end if;

         sCurrentSpeed <= currentSpeed;
      end if;
   end process;


  RefreshsSpriteContent : process (inClock)
    variable oneDimensionalPointer: integer := 0;
  begin
    -- TODO : assert proper height and width
    for i in SPRITE_SIZE.height-1 downto 0 loop
       oneDimensionalPointer := i*SPRITE_WIDTH;
       for o in SPRITE_SIZE.width-1 downto 0 loop
          sSpriteContent(i)(o) <= SPRITE_CONTENT(oneDimensionalPointer+o);
       end loop;
    end loop;
  end process;

  ProcessPosition : process(inClock,
                            sSpritePos,
                            inCursorPos,
                            inEnabled)
    variable vCursor : Pos2D := (0, 0);
    variable vTranslatedCursor: Pos2D := (0, 0);
  begin
      if not inEnabled then
          sShouldDraw <= false;
      elsif rising_edge(inClock) then
          sCenterPos <= sSpritePos;

          vCursor := inCursorPos;

          if   vCursor.x < (sCenterPos.x - C_HALF_SCALED_WIDTH)
            or vCursor.x > (sCenterPos.x + C_HALF_SCALED_WIDTH)
            or vCursor.y < (sCenterPos.y - C_HALF_SCALED_HEIGHT)
            or vCursor.y > (sCenterPos.y + C_HALF_SCALED_HEIGHT)
            then
              sShouldDraw <= false;
          else
             vTranslatedCursor := (((vCursor.x - (sCenterPos.x - C_HALF_SCALED_WIDTH))  / SCALE), 
                                   ((vCursor.y - (sCenterPos.y - C_HALF_SCALED_HEIGHT)) / SCALE));
             -- for rotation, first we do a translation to have the origin in the center of the sprite
             vTranslatedCursor := translateOriginToCenterOfSprite(SPRITE_SIZE, vTranslatedCursor);
             -- then we apply the rotation
             vTranslatedCursor := rotate(SPRITE_SIZE, vTranslatedCursor, std_logic_vector(to_unsigned(sRotation, 5)));
             -- and translate the origin back
             vTranslatedCursor := translateOriginBackToFirstBitCorner(SPRITE_SIZE, vTranslatedCursor);
             -- now we check the sprite content with the transformed cursor
             if vTranslatedCursor.x < 0 or vTranslatedCursor.x > SPRITE_SIZE.width-1
                or vTranslatedCursor.y <0 or vTranslatedCursor.y > SPRITE_SIZE.height-1 then
                sShouldDraw <= false;
             elsif sSpriteContent(vTranslatedCursor.y)(vTranslatedCursor.x) = '1' then
                sShouldDraw <= true;
             else
                sShouldDraw <= false;
             end if;
          end if;
      end if;
  end process;
end logic;
