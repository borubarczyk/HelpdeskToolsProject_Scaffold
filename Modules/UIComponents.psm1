# Interfejs WPF aplikacji Helpdesk Tools.
# Motyw, kontrolki i układ są wspólne z Domain Ops (AD-ManagerDiamond) i ServerReview:
# ciemny motyw, Segoe UI 13, ikony Segoe Fluent Icons / Segoe MDL2 Assets, karty z zaokrągleniami,
# przełącznik przestrzeni roboczych, lista obiektów z zaznaczaniem, nawigacja modułów, tabela wyników,
# panel szczegółów wiersza, dziennik operacji i pasek stanu.

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

#region Motyw (ciemny, spójny z Domain Ops / ServerReview)
$script:ThemeXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <SolidColorBrush x:Key="BgBrush" Color="#0F1318"/>
  <SolidColorBrush x:Key="PanelBrush" Color="#12171D"/>
  <SolidColorBrush x:Key="PanelBorderBrush" Color="#1E242E"/>
  <SolidColorBrush x:Key="CardBrush" Color="#161B22"/>
  <SolidColorBrush x:Key="CardBorderBrush" Color="#242B36"/>
  <SolidColorBrush x:Key="FieldBrush" Color="#1B212A"/>
  <SolidColorBrush x:Key="FieldBorderBrush" Color="#2A323F"/>
  <SolidColorBrush x:Key="HoverBrush" Color="#1A2029"/>
  <SolidColorBrush x:Key="SelectedBrush" Color="#1A2640"/>
  <SolidColorBrush x:Key="SelectedBorderBrush" Color="#2F4478"/>
  <SolidColorBrush x:Key="TextBrush" Color="#E4E8EF"/>
  <SolidColorBrush x:Key="MutedBrush" Color="#8791A5"/>
  <SolidColorBrush x:Key="FaintBrush" Color="#5E6779"/>
  <SolidColorBrush x:Key="AccentBrush" Color="#3E6FE0"/>
  <SolidColorBrush x:Key="FocusBrush" Color="#4C7DF0"/>
  <SolidColorBrush x:Key="OkBrush" Color="#5EE3AE"/>
  <SolidColorBrush x:Key="WarnBrush" Color="#FFC46B"/>
  <SolidColorBrush x:Key="CritBrush" Color="#FF7A86"/>
  <SolidColorBrush x:Key="InfoBrush" Color="#8CC0FF"/>

  <Style x:Key="Card" TargetType="Border">
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="10"/>
    <Setter Property="Padding" Value="16,14"/>
  </Style>

  <Style x:Key="Glyph" TargetType="TextBlock">
    <Setter Property="FontFamily" Value="Segoe Fluent Icons, Segoe MDL2 Assets"/>
    <Setter Property="FontSize" Value="14"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
  </Style>

  <Style x:Key="ScrollThumb" TargetType="Thumb">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Thumb">
          <Border CornerRadius="4" Background="#39414F"/>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ScrollBar">
    <Setter Property="Width" Value="10"/>
    <Setter Property="MinWidth" Value="10"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ScrollBar">
          <Grid Background="Transparent">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" Margin="2"/></Track.Thumb>
            </Track>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <Trigger Property="Orientation" Value="Horizontal">
        <Setter Property="Width" Value="Auto"/>
        <Setter Property="MinWidth" Value="0"/>
        <Setter Property="Height" Value="10"/>
        <Setter Property="MinHeight" Value="10"/>
        <Setter Property="Template">
          <Setter.Value>
            <ControlTemplate TargetType="ScrollBar">
              <Grid Background="Transparent">
                <Track x:Name="PART_Track" IsDirectionReversed="False">
                  <Track.Thumb><Thumb Style="{StaticResource ScrollThumb}" Margin="2"/></Track.Thumb>
                </Track>
              </Grid>
            </ControlTemplate>
          </Setter.Value>
        </Setter>
      </Trigger>
    </Style.Triggers>
  </Style>

  <Style TargetType="Button">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="12,5"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.8"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="#3E6FE0"/>
    <Setter Property="BorderBrush" Value="#3E6FE0"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#5582EC"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Foreground" Value="#FF8A95"/>
    <Setter Property="BorderBrush" Value="#4A2A32"/>
    <Setter Property="Background" Value="#21181C"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#3A1F26"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DangerPrimaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="#D9475A"/>
    <Setter Property="BorderBrush" Value="#D9475A"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#E85C6E"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderBrush" Value="Transparent"/>
    <Setter Property="Foreground" Value="#AEB6C4"/>
    <Setter Property="Padding" Value="8,4"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True">
        <Setter Property="Background" Value="#1E252F"/>
        <Setter Property="Foreground" Value="#E4E8EF"/>
      </Trigger>
    </Style.Triggers>
  </Style>

  <Style TargetType="TextBox">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7">
            <Grid>
              <!-- Padding pola TextBox stosuje sam do tekstu - szablon nie dodaje go drugi raz -->
              <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="{TemplateBinding VerticalContentAlignment}"/>
              <Border Margin="{TemplateBinding Padding}" IsHitTestVisible="False">
                <TextBlock x:Name="wm" Text="{TemplateBinding Tag}" Foreground="#5E6779" Margin="2,0,0,0"
                           VerticalAlignment="{TemplateBinding VerticalContentAlignment}" Visibility="Collapsed"/>
              </Border>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="Text" Value=""><Setter TargetName="wm" Property="Visibility" Value="Visible"/></Trigger>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#39445A"/></Trigger>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="MultiText" TargetType="TextBox" BasedOn="{StaticResource {x:Type TextBox}}">
    <Setter Property="AcceptsReturn" Value="True"/>
    <Setter Property="AcceptsTab" Value="True"/>
    <Setter Property="TextWrapping" Value="NoWrap"/>
    <Setter Property="VerticalContentAlignment" Value="Top"/>
    <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
    <Setter Property="HorizontalScrollBarVisibility" Value="Auto"/>
    <Setter Property="FontFamily" Value="Consolas"/>
    <Setter Property="FontSize" Value="12.5"/>
  </Style>
  <Style x:Key="ReadOnlyText" TargetType="TextBox" BasedOn="{StaticResource MultiText}">
    <Setter Property="IsReadOnly" Value="True"/>
    <Setter Property="AcceptsTab" Value="False"/>
    <Setter Property="TextWrapping" Value="Wrap"/>
    <Setter Property="HorizontalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="BorderThickness" Value="0"/>
  </Style>

  <Style x:Key="GridEditText" TargetType="TextBox">
    <Setter Property="Background" Value="#202A3B"/>
    <Setter Property="Foreground" Value="White"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Padding" Value="0"/>
    <Setter Property="Margin" Value="-6,-3"/>
    <Setter Property="MinHeight" Value="0"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="TextBox">
          <Border Background="{TemplateBinding Background}" BorderBrush="#4C7DF0" BorderThickness="1" CornerRadius="4" Padding="5,2">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="PasswordBox">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#2A323F"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="CaretBrush" Value="#E4E8EF"/>
    <Setter Property="SelectionBrush" Value="#3E6FE0"/>
    <Setter Property="VerticalContentAlignment" Value="Center"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="PasswordBox">
          <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="7">
            <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBox">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="MinHeight" Value="30"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBox">
          <Grid>
            <ToggleButton Focusable="False" ClickMode="Press"
                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
              <ToggleButton.Template>
                <ControlTemplate TargetType="ToggleButton">
                  <Border x:Name="bd" Background="#1B212A" BorderBrush="#2A323F" BorderThickness="1" CornerRadius="7">
                    <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,11,0"
                          Data="M 0 0 L 4 4 L 8 0" Stroke="#8791A5" StrokeThickness="1.6"/>
                  </Border>
                  <ControlTemplate.Triggers>
                    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
                  </ControlTemplate.Triggers>
                </ControlTemplate>
              </ToggleButton.Template>
            </ToggleButton>
            <ContentPresenter IsHitTestVisible="False" Margin="9,0,28,0" VerticalAlignment="Center"
                              Content="{TemplateBinding SelectionBoxItem}"
                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
            <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True"
                   Focusable="False" PopupAnimation="Fade">
              <Border Background="#1B212A" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="7" Margin="0,3,0,0" Padding="3"
                      MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}" MaxHeight="380">
                <ScrollViewer>
                  <StackPanel IsItemsHost="True"/>
                </ScrollViewer>
              </Border>
            </Popup>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ComboBoxItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="10,6"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBoxItem">
          <Border x:Name="bd" Background="Transparent" CornerRadius="5" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="Background" Value="#22304D"/></Trigger>
            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="bd" Property="Background" Value="#2C3B5E"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="CheckBox">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="CheckBox">
          <Grid Background="Transparent">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <!-- 16 px: całe piksele przy skalowaniu 125/150/175% (17 px bywało przycinane od dołu) -->
            <Border x:Name="box" Width="16" Height="16" Margin="0,1" CornerRadius="4" BorderThickness="1" BorderBrush="#3A4352" Background="#1B212A" VerticalAlignment="Center">
              <Grid>
                <Path x:Name="mark" Data="M 3 7.2 L 5.8 10 L 11 4.2" Stroke="White" StrokeThickness="2" Visibility="Collapsed"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round"/>
                <Rectangle x:Name="dash" Width="8" Height="2" Fill="White" Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ContentPresenter x:Name="cp" Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center"/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="Content" Value="{x:Null}"><Setter TargetName="cp" Property="Margin" Value="0"/></Trigger>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="box" Property="BorderBrush" Value="#4C7DF0"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="box" Property="Background" Value="#3E6FE0"/>
              <Setter TargetName="box" Property="BorderBrush" Value="#3E6FE0"/>
              <Setter TargetName="mark" Property="Visibility" Value="Visible"/>
            </Trigger>
            <Trigger Property="IsChecked" Value="{x:Null}">
              <Setter TargetName="box" Property="Background" Value="#2C4A8F"/>
              <Setter TargetName="box" Property="BorderBrush" Value="#3E6FE0"/>
              <Setter TargetName="dash" Property="Visibility" Value="Visible"/>
            </Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="SegmentRadio" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="Padding" Value="12,3"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#28303D"/>
              <Setter Property="Foreground" Value="#E4E8EF"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="SegmentHost" TargetType="Border">
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="CornerRadius" Value="8"/>
    <Setter Property="Padding" Value="2"/>
  </Style>

  <Style x:Key="WorkspaceTab" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="Padding" Value="14,7"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="b" Background="Transparent" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1F2B47"/>
              <Setter Property="Foreground" Value="White"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="NavItem" TargetType="RadioButton">
    <Setter Property="Foreground" Value="#AEB6C4"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Margin" Value="0,1"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Grid>
            <Border x:Name="b" Background="Transparent" CornerRadius="7" Padding="10,7">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
            <Border x:Name="bar" Width="3" CornerRadius="2" Background="#4C7DF0" HorizontalAlignment="Left" Margin="0,8" Visibility="Hidden"/>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2029"/>
              <Setter Property="Foreground" Value="#E4E8EF"/>
            </Trigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2640"/>
              <Setter TargetName="bar" Property="Visibility" Value="Visible"/>
              <Setter Property="Foreground" Value="White"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="NavHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="#5E6779"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="Margin" Value="10,14,0,5"/>
  </Style>

  <Style x:Key="ItemCard" TargetType="ListBoxItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="8,6"/>
    <Setter Property="Margin" Value="0,1"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="b" Background="Transparent" BorderBrush="Transparent" BorderThickness="1" CornerRadius="7" Padding="{TemplateBinding Padding}">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#1A2029"/></Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter TargetName="b" Property="Background" Value="#1A2640"/>
              <Setter TargetName="b" Property="BorderBrush" Value="#2F4478"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="ListBox">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="ItemContainerStyle" Value="{StaticResource ItemCard}"/>
    <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Disabled"/>
    <Setter Property="VirtualizingPanel.IsVirtualizing" Value="True"/>
    <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
  </Style>

  <Style TargetType="ProgressBar">
    <Setter Property="Background" Value="#262D39"/>
    <Setter Property="Foreground" Value="#4C7DF0"/>
    <Setter Property="Height" Value="6"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ProgressBar">
          <Grid>
            <Border x:Name="PART_Track" CornerRadius="3" Background="{TemplateBinding Background}"/>
            <Border x:Name="PART_Indicator" CornerRadius="3" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left"/>
          </Grid>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="GridCell" TargetType="DataGridCell">
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="DataGridCell">
          <Border Background="{TemplateBinding Background}" Padding="10,4">
            <ContentPresenter VerticalAlignment="Center"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
        <Setter Property="Foreground" Value="White"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="BoolCell" TargetType="DataGridCell" BasedOn="{StaticResource GridCell}">
    <Style.Triggers>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Tak"><Setter Property="Foreground" Value="#5EE3AE"/></DataTrigger>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Nie"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="BoolCellInv" TargetType="DataGridCell" BasedOn="{StaticResource GridCell}">
    <Style.Triggers>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Tak"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <DataTrigger Binding="{Binding RelativeSource={RelativeSource Self}, Path=Content.Text}" Value="Nie"><Setter Property="Foreground" Value="#5EE3AE"/></DataTrigger>
      <Trigger Property="IsSelected" Value="True">
        <Setter Property="Background" Value="#233354"/>
      </Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GridRow" TargetType="DataGridRow">
    <Style.Triggers>
      <DataTrigger Binding="{Binding [__flag]}" Value="crit"><Setter Property="Foreground" Value="#FF7A86"/></DataTrigger>
      <DataTrigger Binding="{Binding [__flag]}" Value="warn"><Setter Property="Foreground" Value="#FFC46B"/></DataTrigger>
      <DataTrigger Binding="{Binding [__flag]}" Value="muted"><Setter Property="Foreground" Value="#7B8496"/></DataTrigger>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#1D2430"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="GridHeader" TargetType="DataGridColumnHeader">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="Foreground" Value="#8791A5"/>
    <Setter Property="FontWeight" Value="SemiBold"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="10,8"/>
    <Setter Property="BorderBrush" Value="#252C38"/>
    <Setter Property="BorderThickness" Value="0,0,1,1"/>
  </Style>
  <!-- Lejek filtra w nagłówku kolumny: przygaszony, wyraźny po najechaniu na nagłówek, niebieski gdy filtr jest aktywny (Tag = on) -->
  <Style x:Key="HeaderFilterButton" TargetType="Button">
    <Setter Property="Foreground" Value="#7B8496"/>
    <Setter Property="Opacity" Value="0.45"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Focusable" Value="False"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
    <Setter Property="ToolTip" Value="Filtruj kolumnę"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="Transparent" CornerRadius="4" Padding="4,3">
            <TextBlock Text="&#xE71C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="10.5" Foreground="{TemplateBinding Foreground}" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Background" Value="#2A3342"/><Setter Property="Foreground" Value="#E4E8EF"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
    <Style.Triggers>
      <DataTrigger Binding="{Binding IsMouseOver, RelativeSource={RelativeSource AncestorType=DataGridColumnHeader}}" Value="True"><Setter Property="Opacity" Value="1"/></DataTrigger>
      <Trigger Property="Tag" Value="on"><Setter Property="Opacity" Value="1"/><Setter Property="Foreground" Value="#8CB0FF"/></Trigger>
    </Style.Triggers>
  </Style>
  <Style x:Key="DarkGrid" TargetType="DataGrid">
    <Style.Resources>
      <SolidColorBrush x:Key="{x:Static SystemColors.ControlBrushKey}" Color="#161B22"/>
    </Style.Resources>
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="Foreground" Value="#D5DAE3"/>
    <Setter Property="RowBackground" Value="#161B22"/>
    <Setter Property="AlternatingRowBackground" Value="#181E26"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="GridLinesVisibility" Value="Horizontal"/>
    <Setter Property="HorizontalGridLinesBrush" Value="#1F2530"/>
    <Setter Property="HeadersVisibility" Value="Column"/>
    <Setter Property="IsReadOnly" Value="True"/>
    <Setter Property="CanUserAddRows" Value="False"/>
    <Setter Property="CanUserDeleteRows" Value="False"/>
    <Setter Property="CanUserResizeRows" Value="False"/>
    <Setter Property="SelectionMode" Value="Extended"/>
    <Setter Property="SelectionUnit" Value="FullRow"/>
    <Setter Property="ClipboardCopyMode" Value="IncludeHeader"/>
    <Setter Property="MinRowHeight" Value="28"/>
    <Setter Property="FontSize" Value="12.5"/>
    <Setter Property="EnableRowVirtualization" Value="True"/>
    <Setter Property="EnableColumnVirtualization" Value="True"/>
    <Setter Property="VirtualizingPanel.VirtualizationMode" Value="Recycling"/>
    <Setter Property="ColumnHeaderStyle" Value="{StaticResource GridHeader}"/>
    <Setter Property="CellStyle" Value="{StaticResource GridCell}"/>
    <Setter Property="RowStyle" Value="{StaticResource GridRow}"/>
  </Style>

  <Style TargetType="ContextMenu">
    <Setter Property="Background" Value="#1B212A"/>
    <Setter Property="BorderBrush" Value="#2F3846"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ContextMenu">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="4">
            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle"/>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style TargetType="MenuItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="MenuItem">
          <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="8,6" MinWidth="200">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="26"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <ContentPresenter ContentSource="Icon" VerticalAlignment="Center" TextElement.Foreground="#8791A5"/>
              <ContentPresenter Grid.Column="1" ContentSource="Header" VerticalAlignment="Center"/>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="b" Property="Background" Value="#24304A"/></Trigger>
            <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
  <Style x:Key="MenuSeparator" TargetType="Separator">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Separator">
          <Border Height="1" Background="#2A323F" Margin="6,4"/>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ToolTip">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToolTip">
          <Border Background="#232A35" BorderBrush="#2F3846" BorderThickness="1" CornerRadius="6" Padding="9,6" MaxWidth="460">
            <ContentPresenter>
              <ContentPresenter.Resources>
                <Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/></Style>
              </ContentPresenter.Resources>
            </ContentPresenter>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="TreeView">
    <Style.Resources>
      <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#2A3B63"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="White"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" Color="#24304A"/>
      <SolidColorBrush x:Key="{x:Static SystemColors.InactiveSelectionHighlightTextBrushKey}" Color="White"/>
    </Style.Resources>
    <Setter Property="Background" Value="#161B22"/>
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="BorderBrush" Value="#242B36"/>
    <Setter Property="Padding" Value="6"/>
  </Style>
  <Style TargetType="TreeViewItem">
    <Setter Property="Foreground" Value="#E4E8EF"/>
    <Setter Property="Padding" Value="4,3"/>
  </Style>

  <Style TargetType="GridSplitter">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Focusable" Value="False"/>
    <Style.Triggers>
      <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#2F4478"/></Trigger>
    </Style.Triggers>
  </Style>

  <Style x:Key="Chip" TargetType="Border">
    <Setter Property="Background" Value="#1E252F"/>
    <Setter Property="CornerRadius" Value="9"/>
    <Setter Property="Padding" Value="9,2"/>
    <Setter Property="Margin" Value="0,0,6,0"/>
    <Setter Property="VerticalAlignment" Value="Center"/>
  </Style>
</ResourceDictionary>
'@
#endregion

#region Stan interfejsu
$script:ThemeDoc = $null
$script:Theme = $null
$script:DwmReady = $null

$script:UI = @{
    Window          = $null
    Controls        = @{}
    Workspaces      = [ordered]@{}
    ModuleDefs      = New-Object System.Collections.ArrayList
    Modules         = @{}
    ActiveWorkspace = $null
    ActiveModule    = $null
    Panels          = @{}
    LogItems        = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
    LogUnread       = 0
    LogVisible      = $false
    DetailVisible   = $true
    BusyDepth       = 0
    ConnectButtons  = @{}
}
$Global:HT_UI = $script:UI

# Kolory kropek stanu (lista obiektów, połączenia)
$script:DotColors = @{ unknown = '#3A4352'; ok = '#5EE3AE'; warn = '#FFC46B'; crit = '#FF7A86'; off = '#5E6779'; info = '#8CC0FF' }
#endregion

#region Podstawy: motyw, XAML, pędzle, ikony
function Get-HTTheme {
    # Jedna instancja słownika - style i pędzle dla kontrolek tworzonych w kodzie
    if (-not $script:Theme) { $script:Theme = [System.Windows.Markup.XamlReader]::Parse($script:ThemeXaml) }
    return $script:Theme
}

function Get-HTThemeResource([string]$Key) {
    return (Get-HTTheme)[$Key]
}

function New-HTUiElement {
    # Ładuje XAML z wstrzykniętym motywem: zasoby muszą istnieć w chwili parsowania (StaticResource),
    # dlatego słownik motywu trafia na początek <Root.Resources> korzenia dokumentu.
    param([Parameter(Mandatory)][string]$Xaml)
    if (-not $script:ThemeDoc) {
        $script:ThemeDoc = New-Object System.Xml.XmlDocument
        $script:ThemeDoc.LoadXml($script:ThemeXaml)
    }
    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $false
    $doc.LoadXml($Xaml)
    $root = $doc.DocumentElement
    $resName = $root.LocalName + '.Resources'
    $existing = $null
    foreach ($child in @($root.ChildNodes)) { if ($child.LocalName -eq $resName) { $existing = $child } }
    $dictionary = $doc.ImportNode($script:ThemeDoc.DocumentElement, $true)
    if ($existing) {
        foreach ($child in @($existing.ChildNodes)) { [void]$dictionary.AppendChild($child) }
        [void]$root.RemoveChild($existing)
    }
    $resources = $doc.CreateElement($resName, $root.NamespaceURI)
    [void]$resources.AppendChild($dictionary)
    [void]$root.PrependChild($resources)
    $reader = New-Object System.Xml.XmlNodeReader $doc
    return [System.Windows.Markup.XamlReader]::Load($reader)
}

function Get-HTBrush([string]$Color) {
    $brush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
    $brush.Freeze()
    return $brush
}

function Get-HTGlyph([string]$Code) {
    if (-not $Code) { return '' }
    return [string][char][Convert]::ToInt32($Code, 16)
}

function New-HTGlyphBlock {
    param([string]$Code, [double]$Size = 14, [string]$Color = '')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Style = Get-HTThemeResource 'Glyph'
    $t.Text = Get-HTGlyph $Code
    $t.FontSize = $Size
    if ($Color) { $t.Foreground = Get-HTBrush $Color }
    return $t
}

function New-HTIconContent {
    # Zawartość przycisku: ikona + tekst
    param([string]$Text, [string]$Icon, [double]$IconSize = 13)
    if (-not $Icon) { return $Text }
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $g = New-HTGlyphBlock -Code $Icon -Size $IconSize
    if ($Text) { $g.Margin = '0,0,8,0' }
    [void]$sp.Children.Add($g)
    if ($Text) {
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = $Text
        $t.VerticalAlignment = 'Center'
        [void]$sp.Children.Add($t)
    }
    return $sp
}

function New-HTButton {
    param([string]$Text, [string]$Icon = '', [switch]$Primary, [switch]$Danger, [switch]$Ghost, [string]$ToolTip = '')
    $b = New-Object System.Windows.Controls.Button
    if ($Primary -and $Danger) { $b.Style = Get-HTThemeResource 'DangerPrimaryButton' }
    elseif ($Primary) { $b.Style = Get-HTThemeResource 'PrimaryButton' }
    elseif ($Danger) { $b.Style = Get-HTThemeResource 'DangerButton' }
    elseif ($Ghost) { $b.Style = Get-HTThemeResource 'GhostButton' }
    $b.Content = New-HTIconContent -Text $Text -Icon $Icon
    if ($ToolTip) { $b.ToolTip = $ToolTip }
    return $b
}

function Set-HTDarkTitleBar {
    # Ciemny pasek tytułu (Windows 10 20H1+ / 11). Brak obsługi - okno zostaje z jasnym paskiem.
    param($Window)
    try {
        if ($null -eq $script:DwmReady) {
            $script:DwmReady = $false
            if (-not ('HelpdeskTools.Dwm' -as [type])) {
                Add-Type -Namespace HelpdeskTools -Name Dwm -ErrorAction Stop -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attribute, ref int value, int size);
'@
            }
            $script:DwmReady = $true
        }
        if (-not $script:DwmReady) { return }
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $Window).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        $on = 1
        if ([HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4) -ne 0) {
            [void][HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 19, [ref]$on, 4)
        }
        $caption = 0x001D1712   # #12171D jako COLORREF (0x00BBGGRR) - Windows 11
        [void][HelpdeskTools.Dwm]::DwmSetWindowAttribute($hwnd, 35, [ref]$caption, 4)
    }
    catch { Write-Verbose "Ciemny pasek tytułu niedostępny: $_" }
}

function Update-HTUi {
    # Przetwarza zaległe zdarzenia okna (odświeżenie widoku w trakcie dłuższej operacji)
    try {
        $frame = New-Object System.Windows.Threading.DispatcherFrame
        $callback = [System.Windows.Threading.DispatcherOperationCallback] { param($f) $f.Continue = $false; return $null }
        [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $callback, $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    catch { Write-Verbose "Update-HTUi: $_" }
}

function Get-HTObjectValue {
    param($InputObject, [string]$Name)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Data.DataRowView]) { $InputObject = $InputObject.Row }
    if ($InputObject -is [System.Data.DataRow]) {
        if (-not $InputObject.Table.Columns.Contains($Name)) { return $null }
        $v = $InputObject[$Name]
        if ($v -is [System.DBNull]) { return $null }
        return $v
    }
    if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject[$Name] }
    $p = $InputObject.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function ConvertTo-HTCellValue {
    # Wartość do tabeli: liczby zostają liczbami (sortowanie), daty -> tekst ISO, bool -> Tak/Nie, kolekcje -> tekst
    param($Value)
    if ($null -eq $Value) { return [System.DBNull]::Value }
    if ($Value -is [System.Management.Automation.PSObject]) { $Value = $Value.PSObject.BaseObject }
    if ($Value -is [string]) {
        $display = ConvertTo-HTDisplayValue $Value
        return $display
    }
    if ($Value -is [bool]) { if ($Value) { return 'Tak' } else { return 'Nie' } }
    if ($Value -is [datetime]) {
        if ($Value.Year -lt 1700) { return [System.DBNull]::Value }
        return $Value.ToString('yyyy-MM-dd HH:mm')
    }
    if ($Value -is [datetimeoffset]) { return $Value.LocalDateTime.ToString('yyyy-MM-dd HH:mm') }
    if ($Value -is [enum] -or $Value -is [timespan] -or $Value -is [guid] -or $Value -is [char]) { return [string]$Value }
    if ($Value -is [System.ValueType]) { return $Value }
    return (ConvertTo-HTDisplayValue $Value)
}
#endregion

#region Okna dialogowe
$script:DialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="480" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterOwner"
        ShowInTaskbar="False" Background="#12171D" Foreground="#E4E8EF" FontFamily="Segoe UI" FontSize="13"
        UseLayoutRounding="True" SnapsToDevicePixels="True" TextOptions.TextFormattingMode="Display">
  <Grid Background="#12171D">
  <Grid Margin="22,20,22,18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid Margin="0,0,0,16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Border x:Name="dlgIconTile" Width="38" Height="38" CornerRadius="10" Background="#1A2640" Margin="0,0,14,0" VerticalAlignment="Top">
        <TextBlock x:Name="dlgIcon" Style="{StaticResource Glyph}" FontSize="17" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
      </Border>
      <StackPanel Grid.Column="1" VerticalAlignment="Center">
        <TextBlock x:Name="dlgTitle" FontSize="16" FontWeight="SemiBold" Foreground="White" TextWrapping="Wrap"/>
        <TextBlock x:Name="dlgSubtitle" Foreground="#8791A5" TextWrapping="Wrap" Margin="0,3,0,0"/>
      </StackPanel>
    </Grid>
    <Grid x:Name="dlgBody" Grid.Row="1">
<!--BODY-->
    </Grid>
    <Grid Grid.Row="2" Margin="0,18,0,0">
      <StackPanel x:Name="dlgExtra" Orientation="Horizontal" HorizontalAlignment="Left"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="btnCancel" Content="Anuluj" MinWidth="96" IsCancel="True"/>
        <Button x:Name="btnOk" Content="OK" MinWidth="96" Margin="8,0,0,0" Style="{StaticResource PrimaryButton}" IsDefault="True"/>
      </StackPanel>
    </Grid>
  </Grid>
  </Grid>
</Window>
'@

$script:DialogTones = @{
    info = @{ Back = '#1A2640'; Fore = '#8CB0FF'; Icon = 'E946' }
    ok   = @{ Back = '#15291F'; Fore = '#5EE3AE'; Icon = 'E930' }
    warn = @{ Back = '#2E2616'; Fore = '#FFC46B'; Icon = 'E7BA' }
    crit = @{ Back = '#2E1A1E'; Fore = '#FF7A86'; Icon = 'EA39' }
}

$script:DialogEvents = @{
    Ok     = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        $validate = $w.Tag.Validate
        if ($validate) {
            $ok = $false
            try { $ok = [bool](& $validate $w) }
            catch { Show-HTError 'Nie można zatwierdzić.' $_; return }
            if (-not $ok) { return }
        }
        Close-HTDialog -Window $w -Ok $true
    }
    Cancel = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if (-not $w) { return }
        $w.Tag.Result = $false
        if (-not $w.Tag.Modal) { $w.Close() }
    }
}

function New-HTDialog {
    param(
        [Parameter(Mandatory)][string]$Title,
        [string]$Subtitle = '',
        [string]$Body = '',
        [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info',
        [string]$Icon = '',
        [double]$Width = 480,
        [double]$Height = 0,
        [string]$OkText = 'OK',
        [string]$CancelText = 'Anuluj',
        [switch]$NoCancel,
        [switch]$Danger,
        [switch]$Resizable,
        [scriptblock]$Validate
    )
    $w = New-HTUiElement ($script:DialogXaml.Replace('<!--BODY-->', $Body))
    $w.Title = $Title
    $w.Width = $Width
    if ($Height -gt 0) {
        $w.SizeToContent = 'Manual'
        $w.Height = $Height
    }
    if ($Resizable) {
        $w.ResizeMode = 'CanResizeWithGrip'
        $w.MinWidth = [Math]::Min($Width, 420)
        $w.MinHeight = 260
    }
    $toneDef = $script:DialogTones[$Tone]
    $w.FindName('dlgIconTile').Background = Get-HTBrush $toneDef.Back
    $iconBlock = $w.FindName('dlgIcon')
    $iconBlock.Foreground = Get-HTBrush $toneDef.Fore
    $iconBlock.Text = Get-HTGlyph $(if ($Icon) { $Icon } else { $toneDef.Icon })
    $w.FindName('dlgTitle').Text = $Title
    $sub = $w.FindName('dlgSubtitle')
    if ($Subtitle) { $sub.Text = $Subtitle } else { $sub.Visibility = 'Collapsed' }
    $ok = $w.FindName('btnOk')
    $ok.Content = $OkText
    if ($Danger) { $ok.Style = Get-HTThemeResource 'DangerPrimaryButton' }
    $cancel = $w.FindName('btnCancel')
    $cancel.Content = $CancelText
    if ($NoCancel) {
        $cancel.Visibility = 'Collapsed'
        $ok.IsCancel = $true
    }
    $ok.add_Click($script:DialogEvents.Ok)
    $cancel.add_Click($script:DialogEvents.Cancel)
    $w.Tag = @{ Result = $false; Modal = $false; Validate = $Validate }
    return $w
}

function Invoke-HTDialog {
    # Pokazuje okno modalnie nad oknem głównym; zwraca $true, gdy zatwierdzono
    param([Parameter(Mandatory)][System.Windows.Window]$Window)
    if (-not ($Window.Tag -is [hashtable])) { $Window.Tag = @{} }
    $Window.Tag['Result'] = $false
    $Window.Tag['Modal'] = $true
    $main = $script:UI.Window
    if ($main -and $main.IsVisible -and -not [object]::ReferenceEquals($main, $Window)) { $Window.Owner = $main }
    else {
        $Window.WindowStartupLocation = 'CenterScreen'
        $Window.Topmost = $true
    }
    $Window.add_SourceInitialized({ param($s, $e) Set-HTDarkTitleBar $s })
    [void]$Window.ShowDialog()
    return [bool]$Window.Tag.Result
}

function Close-HTDialog {
    param([Parameter(Mandatory)]$Window, [bool]$Ok)
    $Window.Tag.Result = $Ok
    if ($Window.Tag.Modal) {
        try { $Window.DialogResult = $Ok } catch { try { $Window.Close() } catch { Write-Verbose $_ } }
    }
    else {
        try { $Window.Close() } catch { Write-Verbose $_ }
    }
}

function New-HTDialogText {
    # Akapit tekstu do treści okna (zawijany)
    param([string]$Text, [string]$Color = '#C9D0DC', [double]$Size = 13)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.TextWrapping = 'Wrap'
    $t.Foreground = Get-HTBrush $Color
    $t.FontSize = $Size
    return $t
}

function Show-HTMessage {
    param([string]$Text, [string]$Title = 'Helpdesk Tools', [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info')
    $body = @'
<ScrollViewer MaxHeight="420" VerticalScrollBarVisibility="Auto">
  <TextBlock x:Name="msgText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>
</ScrollViewer>
'@
    $w = New-HTDialog -Title $Title -Body $body -Tone $Tone -NoCancel -Width 500
    $w.FindName('msgText').Text = $Text
    [void](Invoke-HTDialog $w)
}

function Show-HTWarning([string]$Text, [string]$Title = 'Uwaga') {
    Show-HTMessage -Text $Text -Title $Title -Tone 'warn'
}

function Show-HTError {
    param([string]$Text, $ErrorObject = $null)
    $detail = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ErrorObject.Exception.Message }
    elseif ($ErrorObject -is [System.Exception]) { $ErrorObject.Message }
    elseif ($ErrorObject) { [string]$ErrorObject }
    else { '' }
    $message = if ($detail) { "$Text`r`n`r`n$detail" } else { $Text }
    Show-HTMessage -Text $message -Title 'Błąd' -Tone 'crit'
}

# Zgodność z wcześniejszym API (MessageBox): zwraca 'OK', 'Cancel', 'Yes' albo 'No'
function Show-Dialog {
    param (
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel")][string]$Buttons = "OK",
        [ValidateSet("Info", "Error", "Warning", "Question")][string]$Type = "Info",
        [string]$Title = "Helpdesk Tools"
    )
    $tone = switch ($Type) { "Error" { 'crit' } "Warning" { 'warn' } default { 'info' } }
    $icon = if ($Type -eq 'Question') { 'E9CE' } else { '' }
    if ($Buttons -eq 'OK') {
        Show-HTMessage -Text $Message -Title $Title -Tone $tone
        return 'OK'
    }
    $yesNo = $Buttons -like 'YesNo*'
    $body = '<TextBlock x:Name="msgText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>'
    $w = New-HTDialog -Title $Title -Body $body -Tone $tone -Icon $icon -Width 500 `
        -OkText $(if ($yesNo) { 'Tak' } else { 'OK' }) -CancelText $(if ($yesNo) { 'Nie' } else { 'Anuluj' })
    $w.FindName('msgText').Text = $Message
    $ok = Invoke-HTDialog $w
    if ($yesNo) { if ($ok) { return 'Yes' } else { return 'No' } }
    if ($ok) { return 'OK' } else { return 'Cancel' }
}

function Show-HTConfirm {
    <#
        Pytanie z (opcjonalną) listą obiektów, których dotyczy operacja. Zwraca $true/$false.
        -TypeToConfirm: operacja nieodwracalna - użytkownik musi przepisać podany tekst.
    #>
    param(
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = 'Potwierdzenie',
        [string[]]$Items = @(),
        [string]$ConfirmText = 'Wykonaj',
        [string]$TypeToConfirm = '',
        [switch]$Warning,
        [switch]$Danger
    )
    $body = @'
<StackPanel>
  <TextBlock x:Name="cfText" TextWrapping="Wrap" Foreground="#C9D0DC" LineHeight="19"/>
  <Border x:Name="cfListHost" Style="{StaticResource Card}" Padding="12,8" Margin="0,14,0,0" Visibility="Collapsed">
    <ScrollViewer MaxHeight="220" VerticalScrollBarVisibility="Auto">
      <TextBlock x:Name="cfList" Foreground="#AEB6C4" FontSize="12.5" LineHeight="19" TextWrapping="Wrap"/>
    </ScrollViewer>
  </Border>
  <StackPanel x:Name="cfTypeHost" Margin="0,14,0,0" Visibility="Collapsed">
    <TextBlock x:Name="cfTypeLabel" Foreground="#8791A5" FontSize="12" TextWrapping="Wrap" Margin="0,0,0,5"/>
    <TextBox x:Name="cfType"/>
  </StackPanel>
</StackPanel>
'@
    $tone = if ($Danger) { 'crit' } elseif ($Warning) { 'warn' } else { 'info' }
    $w = New-HTDialog -Title $Title -Body $body -Tone $tone -Icon $(if (-not $Danger -and -not $Warning) { 'E9CE' } else { '' }) -OkText $ConfirmText -Danger:$Danger -Width 520 -Validate {
        param($w)
        $expected = $w.Tag.TypeToConfirm
        if ($expected -and $w.FindName('cfType').Text.Trim() -ne $expected) {
            Show-HTWarning "Aby potwierdzić, wpisz dokładnie: $expected"
            return $false
        }
        return $true
    }
    $w.Tag.TypeToConfirm = $TypeToConfirm
    $w.FindName('cfText').Text = $Message
    if ($Items.Count -gt 0) {
        $shown = @($Items | Select-Object -First 30)
        $text = ($shown | ForEach-Object { "•  $_" }) -join "`n"
        if ($Items.Count -gt $shown.Count) { $text += "`n… i $($Items.Count - $shown.Count) więcej" }
        $w.FindName('cfList').Text = $text
        $w.FindName('cfListHost').Visibility = 'Visible'
    }
    if ($TypeToConfirm) {
        $w.FindName('cfTypeLabel').Text = "Operacja jest nieodwracalna. Aby kontynuować, wpisz: $TypeToConfirm"
        $w.FindName('cfTypeHost').Visibility = 'Visible'
        $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('cfType').Focus() })
    }
    return (Invoke-HTDialog $w)
}

function Show-InputBox {
    # Pole tekstowe w oknie; zwraca tekst albo $null (anulowano)
    param (
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Title = "Wprowadź wartość",
        [ValidateSet("Text", "Email", "Phone", "Url", "Upn", "Guid")][string]$ValidationType = "Text",
        [string]$DefaultText = "",
        [string]$Placeholder = "",
        [switch]$AllowEmpty,
        [switch]$Password,
        [switch]$Multiline,
        [string]$Icon = 'E70F'
    )
    $body = if ($Password) { '<PasswordBox x:Name="inPass"/>' }
    elseif ($Multiline) { '<TextBox x:Name="inText" Style="{StaticResource MultiText}" MinHeight="220"/>' }
    else { '<TextBox x:Name="inText"/>' }
    $w = New-HTDialog -Title $Title -Subtitle $Prompt -Body $body -Icon $Icon -Width $(if ($Multiline) { 620 } else { 500 }) -Height $(if ($Multiline) { 470 } else { 0 }) -Resizable:$Multiline -Validate {
        param($w)
        $value = if ($w.Tag.Password) { $w.FindName('inPass').Password } else { $w.FindName('inText').Text.Trim() }
        if (-not $value) {
            if ($w.Tag.AllowEmpty) { return $true }
            Show-HTWarning 'Pole nie może być puste.'
            return $false
        }
        if (-not $w.Tag.Multiline -and -not (Test-HTInputValue -Value $value -ValidationType $w.Tag.ValidationType)) {
            $messages = @{
                Text = 'Pole nie może być puste.'; Email = 'Nieprawidłowy adres e-mail.'; Upn = 'Nieprawidłowa nazwa UPN (np. jan.kowalski@firma.pl).'
                Phone = 'Nieprawidłowy numer telefonu.'; Url = 'Nieprawidłowy adres URL (https://...).'; Guid = 'Nieprawidłowy identyfikator GUID.'
            }
            Show-HTWarning $messages[$w.Tag.ValidationType]
            return $false
        }
        return $true
    }
    $w.Tag.ValidationType = $ValidationType
    $w.Tag.AllowEmpty = [bool]$AllowEmpty
    $w.Tag.Password = [bool]$Password
    $w.Tag.Multiline = [bool]$Multiline
    if ($Password) {
        $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('inPass').Focus() })
    }
    else {
        $box = $w.FindName('inText')
        $box.Text = $DefaultText
        if ($Placeholder) { $box.Tag = $Placeholder }
        if ($Multiline) { $w.FindName('btnOk').IsDefault = $false }
        $w.add_ContentRendered({ param($s, $e) $b = $s.FindName('inText'); [void]$b.Focus(); $b.SelectAll() })
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    if ($Password) { return $w.FindName('inPass').Password }
    return $w.FindName('inText').Text.Trim()
}

$script:FormEvents = @{
    NumericInput = {
        param($s, $e)
        if ($e.Text -notmatch '^\d+$') { $e.Handled = $true }
    }
}

function Show-HTFormDialog {
    <#
        Formularz w oknie. -Fields: tablica hashtabel:
          @{ Name; Label; Type = Text|Password|Multiline|Combo|Check|Date|Number|Info|Header; Default; Options;
             Required; Validation; Editable; Optional; DateOnly; Min; Max; Placeholder; Hint }
        Zwraca słownik Name -> wartość albo $null (anulowano).
    #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Fields,
        [string]$Description = '',
        [string]$OkText = 'Zapisz',
        [string]$Icon = 'E70F',
        [double]$Width = 560,
        [double]$MaxHeight = 560,
        [switch]$Danger,
        # Dodatkowe przyciski po lewej stronie: @{ Text; Icon; OnClick = { param($w) } }
        [object[]]$ExtraButtons = @()
    )
    $w = New-HTDialog -Title $Title -Subtitle $Description -Body ('<ScrollViewer MaxHeight="{0}" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="fmHost" Margin="0,0,6,0"/></ScrollViewer>' -f [int]$MaxHeight) `
        -Icon $Icon -OkText $OkText -Width $Width -Danger:$Danger -Validate {
        param($w)
        foreach ($entry in $w.Tag.Controls.Values) {
            $f = $entry.Field
            $value = Get-HTFormControlValue -Entry $entry
            $label = [string]$f.Label
            switch ($entry.Type) {
                { $_ -in 'Text', 'Password', 'Multiline', 'Combo' } {
                    if ($f.Required -and -not "$value") { Show-HTWarning "Pole '$label' jest wymagane."; return $false }
                    if ("$value" -and $f.Validation -and -not (Test-HTInputValue -Value "$value" -ValidationType $f.Validation)) {
                        Show-HTWarning "Pole '$label' ma nieprawidłowy format."; return $false
                    }
                }
                'Number' {
                    $n = 0
                    if (-not [int]::TryParse($entry.Control.Text.Trim(), [ref]$n)) { Show-HTWarning "Pole '$label' musi być liczbą."; return $false }
                    if ($null -ne $f.Min -and $n -lt $f.Min) { Show-HTWarning "Pole '$label': minimalna wartość to $($f.Min)."; return $false }
                    if ($null -ne $f.Max -and $n -gt $f.Max) { Show-HTWarning "Pole '$label': maksymalna wartość to $($f.Max)."; return $false }
                }
                'Date' {
                    $text = $entry.Control.Text.Trim()
                    if (-not $text) {
                        if ($f.Optional) { continue }
                        Show-HTWarning "Pole '$label' jest wymagane."; return $false
                    }
                    $d = [datetime]::MinValue
                    $formats = [string[]]@('yyyy-MM-dd HH:mm', 'yyyy-MM-dd', 'yyyy-MM-dd H:mm')
                    if (-not [datetime]::TryParseExact($text, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) {
                        Show-HTWarning "Pole '$label': podaj datę w formacie RRRR-MM-DD GG:MM."; return $false
                    }
                }
            }
        }
        return $true
    }
    $stack = $w.FindName('fmHost')
    $controls = [ordered]@{}
    $first = $true
    foreach ($f in $Fields) {
        $type = if ($f.Type) { [string]$f.Type } else { 'Text' }
        if ($type -eq 'Header') {
            $hd = New-HTDialogText -Text ([string]$f.Label) -Color '#8CB0FF' -Size 13.5
            $hd.FontWeight = 'SemiBold'
            $hd.Margin = $(if ($first) { '0,0,0,2' } else { '0,20,0,2' })
            [void]$stack.Children.Add($hd)
            $line = New-Object System.Windows.Controls.Border
            $line.Height = 1
            $line.Background = Get-HTBrush '#242B36'
            $line.Margin = '0,4,0,4'
            [void]$stack.Children.Add($line)
            $first = $true
            continue
        }
        if ($type -eq 'Info') {
            $info = New-HTDialogText -Text ([string]$f.Label) -Color '#7B8496' -Size 12
            $info.Margin = $(if ($first) { '0,0,0,4' } else { '0,12,0,4' })
            [void]$stack.Children.Add($info)
            $first = $false
            continue
        }
        if ($type -ne 'Check') {
            $caption = [string]$f.Label + $(if ($f.Required) { ' *' } else { '' })
            $lbl = New-HTDialogText -Text $caption -Color '#8791A5' -Size 12
            $lbl.Margin = $(if ($first) { '0,0,0,5' } else { '0,12,0,5' })
            [void]$stack.Children.Add($lbl)
        }
        $ctl = $null
        switch ($type) {
            'Combo' {
                $ctl = New-Object System.Windows.Controls.ComboBox
                foreach ($i in @($f.Options)) { if ($null -ne $i) { [void]$ctl.Items.Add([string]$i) } }
                if ($f.Editable) { $ctl.IsEditable = $true; $ctl.Text = [string]$f.Default }
                $index = if ($null -ne $f.Default) { $ctl.Items.IndexOf([string]$f.Default) } else { -1 }
                if ($index -ge 0) { $ctl.SelectedIndex = $index }
                elseif (-not $f.Editable -and $ctl.Items.Count -gt 0) { $ctl.SelectedIndex = 0 }
            }
            'Check' {
                $ctl = New-Object System.Windows.Controls.CheckBox
                $cbText = New-Object System.Windows.Controls.TextBlock
                $cbText.Text = [string]$f.Label
                $cbText.TextWrapping = 'Wrap'
                $ctl.Content = $cbText
                $ctl.IsChecked = [bool]$f.Default
                $ctl.Margin = $(if ($first) { '0,0,0,0' } else { '0,12,0,0' })
            }
            'Multiline' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Style = Get-HTThemeResource 'MultiText'
                $ctl.FontFamily = 'Segoe UI'
                $ctl.FontSize = 13
                $ctl.TextWrapping = 'Wrap'
                $ctl.Height = $(if ($f.Height) { [double]$f.Height } else { 110 })
                $ctl.Text = [string]$f.Default
            }
            'Password' {
                $ctl = New-Object System.Windows.Controls.PasswordBox
                if ($f.Default) { $ctl.Password = [string]$f.Default }
            }
            'Number' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Width = 130
                $ctl.HorizontalAlignment = 'Left'
                $ctl.HorizontalContentAlignment = 'Right'
                $ctl.Text = $(if ($null -ne $f.Default) { [string]$f.Default } elseif ($null -ne $f.Min) { [string]$f.Min } else { '0' })
                $ctl.add_PreviewTextInput($script:FormEvents.NumericInput)
            }
            'Date' {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Width = 200
                $ctl.HorizontalAlignment = 'Left'
                $format = if ($f.DateOnly) { 'yyyy-MM-dd' } else { 'yyyy-MM-dd HH:mm' }
                $ctl.Tag = $(if ($f.DateOnly) { 'RRRR-MM-DD' } else { 'RRRR-MM-DD GG:MM' })
                if ($f.Default -is [datetime]) { $ctl.Text = $f.Default.ToString($format) }
            }
            default {
                $ctl = New-Object System.Windows.Controls.TextBox
                $ctl.Text = [string]$f.Default
            }
        }
        if ($f.Placeholder -and $ctl -is [System.Windows.Controls.TextBox]) { $ctl.Tag = [string]$f.Placeholder }
        if ($f.ToolTip) { $ctl.ToolTip = [string]$f.ToolTip }
        [void]$stack.Children.Add($ctl)
        if ($f.Hint) {
            $hint = New-HTDialogText -Text ([string]$f.Hint) -Color '#6B7487' -Size 11.5
            $hint.Margin = '1,5,0,0'
            [void]$stack.Children.Add($hint)
        }
        $controls[[string]$f.Name] = @{ Type = $type; Control = $ctl; Field = $f }
        $first = $false
    }
    $w.Tag.Controls = $controls
    foreach ($extra in $ExtraButtons) {
        $eb = New-HTButton -Text ([string]$extra.Text) -Icon ([string]$extra.Icon)
        $eb.Margin = '0,0,8,0'
        $eb.Tag = $extra.OnClick
        $eb.add_Click({
                param($s, $e)
                try { $null = & $s.Tag ([System.Windows.Window]::GetWindow($s)) }
                catch { Show-HTError 'Operacja nie powiodła się.' $_ }
            })
        [void]$w.FindName('dlgExtra').Children.Add($eb)
    }
    $w.add_ContentRendered({
            param($s, $e)
            foreach ($c in $s.Tag.Controls.Values) {
                if ($c.Control -is [System.Windows.Controls.TextBox]) { [void]$c.Control.Focus(); $c.Control.SelectAll(); break }
            }
        })
    if (@($Fields | Where-Object { $_.Type -eq 'Multiline' }).Count -gt 0) { $w.FindName('btnOk').IsDefault = $false }
    if (-not (Invoke-HTDialog $w)) { return $null }

    $result = [ordered]@{}
    foreach ($name in $controls.Keys) { $result[$name] = Get-HTFormControlValue -Entry $controls[$name] }
    return $result
}

function Get-HTFormControlValue {
    param([Parameter(Mandatory)][hashtable]$Entry)
    $c = $Entry.Control
    switch ($Entry.Type) {
        'Combo' { if ($c.IsEditable) { return ([string]$c.Text).Trim() } else { return [string]$c.SelectedItem } }
        'Check' { return ($c.IsChecked -eq $true) }
        'Password' { return $c.Password }
        'Number' { $n = 0; [void][int]::TryParse($c.Text.Trim(), [ref]$n); return $n }
        'Date' {
            $text = $c.Text.Trim()
            if (-not $text) { return $null }
            $d = [datetime]::MinValue
            $formats = [string[]]@('yyyy-MM-dd HH:mm', 'yyyy-MM-dd', 'yyyy-MM-dd H:mm')
            if ([datetime]::TryParseExact($text, $formats, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$d)) { return $d }
            return $null
        }
        'Multiline' { return ([string]$c.Text).Trim() }
        default { return ([string]$c.Text).Trim() }
    }
}

function Show-HTChoiceDialog {
    # Wybór jednej z opcji. Choices: tablica tekstów lub @{ Key; Text; Description; Icon (kod glifu); Style = Danger }
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][object[]]$Choices, [string]$Prompt = '', [string]$Icon = 'E8FD')
    $w = New-HTDialog -Title $Title -Subtitle $Prompt -Body '<StackPanel x:Name="chHost"/>' -Icon $Icon -Width 520
    $w.FindName('btnOk').Visibility = 'Collapsed'
    $hostPanel = $w.FindName('chHost')
    foreach ($choice in $Choices) {
        $c = if ($choice -is [string]) { @{ Key = $choice; Text = $choice } } else { $choice }
        $b = New-Object System.Windows.Controls.Button
        $b.HorizontalContentAlignment = 'Stretch'
        $b.Padding = '14,9'
        $b.Margin = '0,0,0,6'
        if ($c.Style -eq 'Danger') { $b.Style = Get-HTThemeResource 'DangerButton' }
        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition
        $c1.Width = [System.Windows.GridLength]::Auto
        [void]$grid.ColumnDefinitions.Add($c1)
        [void]$grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
        $glyph = New-HTGlyphBlock -Code $(if ($c.Icon) { $c.Icon } else { 'E76C' }) -Size 16 -Color $(if ($c.Style -eq 'Danger') { '#FF8A95' } else { '#8CB0FF' })
        $glyph.Margin = '0,0,14,0'
        [void]$grid.Children.Add($glyph)
        $texts = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = [string]$c.Text
        $t1.FontWeight = 'SemiBold'
        $t1.TextWrapping = 'Wrap'
        [void]$texts.Children.Add($t1)
        if ($c.Description) {
            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = [string]$c.Description
            $t2.Foreground = Get-HTBrush '#8791A5'
            $t2.FontSize = 12
            $t2.TextWrapping = 'Wrap'
            [void]$texts.Children.Add($t2)
        }
        [System.Windows.Controls.Grid]::SetColumn($texts, 1)
        [void]$grid.Children.Add($texts)
        $b.Content = $grid
        $b.Tag = $(if ($c.Key) { $c.Key } else { $c.Text })
        $b.add_Click({
                param($s, $e)
                $win = [System.Windows.Window]::GetWindow($s)
                $win.Tag.Choice = $s.Tag
                Close-HTDialog -Window $win -Ok $true
            })
        [void]$hostPanel.Children.Add($b)
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    return $w.Tag.Choice
}

function Show-HTTextDialog {
    param([string]$Title, [string]$Text, [string]$Subtitle = '')
    $body = '<TextBox x:Name="txText" Style="{StaticResource MultiText}" IsReadOnly="True" TextWrapping="NoWrap"/>'
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $body -Icon 'E8A5' -OkText 'Zamknij' -NoCancel -Width 920 -Height 640 -Resizable
    $box = $w.FindName('txText')
    $box.Text = ($Text -replace "`r?`n", "`r`n")
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8'
    $copy.add_Click({
            param($s, $e)
            $t = [System.Windows.Window]::GetWindow($s).FindName('txText').Text
            if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano do schowka.' 'ok' }
        })
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    [void](Invoke-HTDialog $w)
}

function Show-HTSecretDialog {
    # Dane poufne (hasła, klucze) z przyciskami kopiowania. Items: @{ Label; Value }
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][object[]]$Items, [string]$Description = '')
    if (-not $Description) { $Description = 'Dane poufne - nie przekazuj ich niezabezpieczonym kanałem. Skopiowane hasło zniknie ze schowka po 60 sekundach.' }
    $w = New-HTDialog -Title $Title -Subtitle $Description -Body '<StackPanel x:Name="scHost"/>' -Tone 'warn' -Icon 'E72E' -OkText 'Zamknij' -NoCancel -Width 600
    $hostPanel = $w.FindName('scHost')
    $first = $true
    foreach ($item in $Items) {
        $lbl = New-HTDialogText -Text ([string]$item.Label) -Color '#8791A5' -Size 12
        $lbl.Margin = $(if ($first) { '0,0,0,5' } else { '0,12,0,5' })
        [void]$hostPanel.Children.Add($lbl)
        $dock = New-Object System.Windows.Controls.DockPanel
        $btn = New-HTButton -Icon 'E8C8' -ToolTip 'Kopiuj'
        $btn.Margin = '6,0,0,0'
        [System.Windows.Controls.DockPanel]::SetDock($btn, 'Right')
        [void]$dock.Children.Add($btn)
        $box = New-Object System.Windows.Controls.TextBox
        $box.IsReadOnly = $true
        $box.FontFamily = 'Consolas'
        $box.FontSize = 14
        $box.Text = [string]$item.Value
        [void]$dock.Children.Add($box)
        $btn.Tag = $box
        $btn.add_Click({
                param($s, $e)
                Set-HTClipboard -Text $s.Tag.Text -Secret
                Show-HTToast 'Skopiowano do schowka (zostanie wyczyszczony po 60 s).' 'ok'
            })
        [void]$hostPanel.Children.Add($dock)
        $first = $false
    }
    [void](Invoke-HTDialog $w)
}
#endregion

#region Tabele w oknach (wybór obiektów, podgląd danych)
function New-HTDataTable {
    # Tabela danych dla siatki: kolumny z definicji (Text, Property albo Expression), ukryte __i (indeks) i __search
    param([object[]]$Items, [object[]]$Columns)
    $table = New-Object System.Data.DataTable 'Dane'
    [void]$table.Columns.Add('__i', [int])
    [void]$table.Columns.Add('__search', [string])
    foreach ($c in $Columns) { if (-not $table.Columns.Contains($c.Text)) { [void]$table.Columns.Add($c.Text, [object]) } }
    $table.BeginLoadData()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $row = $table.NewRow()
        $row['__i'] = $i
        $sb = New-Object System.Text.StringBuilder
        foreach ($c in $Columns) {
            $raw = if ($c.Expression) { & $c.Expression $Items[$i] } else { Get-HTObjectValue $Items[$i] $c.Property }
            $v = ConvertTo-HTCellValue $raw
            $row[$c.Text] = $v
            if ($v -isnot [System.DBNull]) { [void]$sb.Append([string]$v).Append(' ') }
        }
        $row['__search'] = $sb.ToString().ToLowerInvariant()
        $table.Rows.Add($row)
    }
    $table.EndLoadData()
    return $table
}

function Get-HTDefaultColumns {
    param([object[]]$Items, [int]$Max = 12)
    $first = @($Items)[0]
    if ($null -eq $first) { return @() }
    if ($first -is [string]) { return @(@{ Text = 'Nazwa'; Property = '__value' }) }
    return @($first.PSObject.Properties | Select-Object -First $Max | ForEach-Object { @{ Text = $_.Name; Property = $_.Name } })
}

function Add-HTGridColumns {
    param($Grid, [object[]]$Columns)
    $Grid.Columns.Clear()
    foreach ($c in $Columns) {
        $col = New-Object System.Windows.Controls.DataGridTextColumn
        $col.Header = $c.Text
        $col.Binding = New-Object System.Windows.Data.Binding ('[' + $c.Text + ']')
        $col.SortMemberPath = $c.Text
        $col.MaxWidth = 520
        $col.MinWidth = 54
        if ($c.Width) { $col.Width = New-Object System.Windows.Controls.DataGridLength ([double]$c.Width) }
        $style = New-Object System.Windows.Style ([System.Windows.Controls.TextBlock])
        $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextTrimmingProperty, [System.Windows.TextTrimming]::CharacterEllipsis)))
        $col.ElementStyle = $style
        $Grid.Columns.Add($col)
    }
}

function Set-HTViewFilter {
    param([System.Data.DataView]$View, [string]$Text)
    $terms = @("$Text".Trim().ToLowerInvariant() -split '\s+' | Where-Object { $_ })
    $parts = foreach ($t in $terms) {
        $lit = ConvertTo-HTLikeLiteral ($(if ($t.StartsWith('-') -and $t.Length -gt 1) { $t.Substring(1) } else { $t }))
        if ($t.StartsWith('-') -and $t.Length -gt 1) { "__search NOT LIKE '*$lit*'" } else { "__search LIKE '*$lit*'" }
    }
    try { $View.RowFilter = (@($parts) -join ' AND ') } catch { $View.RowFilter = '' }
}

function ConvertTo-HTLikeLiteral {
    # Tekst do wzorca LIKE w filtrze DataView: znaki specjalne w nawiasach kwadratowych
    param([string]$Text)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Text.ToCharArray()) {
        switch ($ch) {
            '[' { [void]$sb.Append('[[]') }
            ']' { [void]$sb.Append('[]]') }
            '*' { [void]$sb.Append('[*]') }
            '%' { [void]$sb.Append('[%]') }
            "'" { [void]$sb.Append("''") }
            default { [void]$sb.Append($ch) }
        }
    }
    return $sb.ToString()
}

$script:GridDialogXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*"/>
  </Grid.RowDefinitions>
  <Grid Margin="0,0,0,8">
    <TextBox x:Name="gdSearch" Tag="Szukaj… (słowo z minusem wyklucza)" Width="320" HorizontalAlignment="Left"/>
    <Border Style="{StaticResource Chip}" HorizontalAlignment="Right">
      <TextBlock x:Name="gdCount" Foreground="#AEB6C4" FontSize="11.5"/>
    </Border>
  </Grid>
  <Border Grid.Row="1" Style="{StaticResource Card}" Padding="0">
    <DataGrid x:Name="gdGrid" Style="{StaticResource DarkGrid}" AutoGenerateColumns="False" Margin="1"/>
  </Border>
</Grid>
'@

$script:GridDialogEvents = @{
    Search = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $view = $w.Tag.View
        Set-HTViewFilter -View $view -Text $s.Text
        $w.FindName('gdCount').Text = if ($view.Count -eq $view.Table.Rows.Count) { [string]$view.Count } else { "$($view.Count) z $($view.Table.Rows.Count)" }
    }
}

function New-HTGridDialog {
    param([string]$Title, [string]$Subtitle, [object[]]$Items, [object[]]$Columns, [string]$Icon, [string]$OkText, [switch]$NoCancel, [switch]$Multi)
    $w = New-HTDialog -Title $Title -Subtitle $Subtitle -Body $script:GridDialogXaml -Icon $Icon -OkText $OkText -NoCancel:$NoCancel -Width 960 -Height 640 -Resizable
    $table = New-HTDataTable -Items $Items -Columns $Columns
    $view = [System.Data.DataView]::new($table)
    $grid = $w.FindName('gdGrid')
    Add-HTGridColumns -Grid $grid -Columns $Columns
    $grid.SelectionMode = $(if ($Multi) { 'Extended' } else { 'Single' })
    $grid.ItemsSource = $view
    $w.Tag.View = $view
    $w.Tag.Items = $Items
    $w.Tag.Columns = $Columns
    $w.FindName('gdCount').Text = [string]$table.Rows.Count
    $w.FindName('gdSearch').add_TextChanged($script:GridDialogEvents.Search)
    $w.add_ContentRendered({ param($s, $e) [void]$s.FindName('gdSearch').Focus() })
    return $w
}

function Show-HTSelectionDialog {
    # Wybór obiektów z listy (wyszukiwanie, sortowanie). Zwraca wybrane obiekty albo $null.
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][object[]]$Items,
        [object[]]$Columns,
        [string]$Prompt = '',
        [switch]$MultiSelect,
        [string]$OkText = 'Wybierz',
        [string]$Icon = 'E8B3'
    )
    $Items = @($Items | Where-Object { $null -ne $_ })
    if ($Items.Count -eq 0) {
        Show-HTMessage -Text 'Brak elementów do wyboru.' -Title $Title
        return $null
    }
    $isString = $Items[0] -is [string]
    if ($isString) {
        $Items = @($Items | ForEach-Object { [PSCustomObject]@{ Nazwa = $_ } })
        $Columns = @(@{ Text = 'Nazwa'; Property = 'Nazwa' })
    }
    if (-not $Columns) { $Columns = Get-HTDefaultColumns -Items $Items }
    $hint = if ($MultiSelect) { 'Ctrl / Shift - zaznaczanie wielu pozycji.' } else { 'Dwuklik wybiera pozycję.' }
    $w = New-HTGridDialog -Title $Title -Subtitle $(if ($Prompt) { "$Prompt  $hint" } else { $hint }) -Items $Items -Columns $Columns -Icon $Icon -OkText $OkText -Multi:$MultiSelect
    $w.Tag.Validate = {
        param($w)
        if ($w.FindName('gdGrid').SelectedItems.Count -eq 0) { Show-HTWarning 'Zaznacz co najmniej jedną pozycję.'; return $false }
        return $true
    }
    if (-not $MultiSelect) {
        $w.FindName('gdGrid').add_MouseDoubleClick({
                param($s, $e)
                if ($s.SelectedItems.Count -gt 0) { Close-HTDialog -Window ([System.Windows.Window]::GetWindow($s)) -Ok $true }
            })
    }
    if (-not (Invoke-HTDialog $w)) { return $null }
    $selected = foreach ($drv in @($w.FindName('gdGrid').SelectedItems)) { $Items[[int]$drv.Row['__i']] }
    if ($isString) { return @($selected | ForEach-Object { $_.Nazwa }) }
    return @($selected)
}

function Show-HTDataViewer {
    # Podgląd danych tabelarycznych z wyszukiwaniem, kopiowaniem i eksportem CSV
    param(
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][AllowNull()][object[]]$Data,
        [object[]]$Columns,
        [string]$Description = '',
        [string]$ExportName = 'eksport',
        [string]$Icon = 'E8A5'
    )
    $Data = @($Data | Where-Object { $null -ne $_ })
    if ($Data.Count -eq 0) {
        Show-HTMessage -Text 'Brak danych do wyświetlenia.' -Title $Title
        return
    }
    if (-not $Columns) { $Columns = Get-HTDefaultColumns -Items $Data -Max 30 }
    $w = New-HTGridDialog -Title $Title -Subtitle $Description -Items $Data -Columns $Columns -Icon $Icon -OkText 'Zamknij' -NoCancel -Multi
    $w.Tag.ExportName = $ExportName
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8' -ToolTip 'Kopiuj zaznaczone wiersze (lub wszystkie) w formacie Excel'
    $copy.Margin = '0,0,8,0'
    $copy.add_Click({
            param($s, $e)
            $win = [System.Windows.Window]::GetWindow($s)
            $grid = $win.FindName('gdGrid')
            $rows = if ($grid.SelectedItems.Count -gt 0) { @($grid.SelectedItems) } else { @($win.Tag.View) }
            $lines = @(($win.Tag.Columns | ForEach-Object { $_.Text }) -join "`t")
            foreach ($drv in $rows) { $lines += (($win.Tag.Columns | ForEach-Object { ([string](Get-HTObjectValue $drv $_.Text)) -replace "[`t`r`n]+", ' ' }) -join "`t") }
            Set-HTClipboard ($lines -join "`r`n")
            Show-HTToast "Skopiowano wierszy: $($rows.Count)." 'ok'
        })
    $export = New-HTButton -Text 'Eksport CSV' -Icon 'EDE1'
    $export.add_Click({
            param($s, $e)
            $win = [System.Windows.Window]::GetWindow($s)
            $rows = foreach ($drv in @($win.Tag.View)) {
                $o = [ordered]@{}
                foreach ($c in $win.Tag.Columns) { $v = Get-HTObjectValue $drv $c.Text; $o[$c.Text] = if ($null -eq $v) { '' } else { [string]$v } }
                [PSCustomObject]$o
            }
            Save-ContentToFile -Data @($rows) -Format 'csv' -Title 'Eksport danych' -DefaultName $win.Tag.ExportName | Out-Null
        })
    [void]$w.FindName('dlgExtra').Children.Add($copy)
    [void]$w.FindName('dlgExtra').Children.Add($export)
    [void](Invoke-HTDialog $w)
}
#endregion

#region Toasty, schowek
$script:ToastTimers = New-Object 'System.Collections.Generic.Dictionary[object,object]'
$script:Clipboard = @{ Secret = $null; Timer = $null }

function Show-HTToast {
    # Krótkie powiadomienie w prawym dolnym rogu okna (znika samo)
    param([Parameter(Mandatory)][string]$Text, [ValidateSet('info', 'ok', 'warn', 'crit')][string]$Tone = 'info', [int]$Seconds = 4)
    $toastHost = $script:UI.Controls['toastHost']
    if (-not $toastHost) { return }
    try {
        $toneDef = $script:DialogTones[$Tone]
        $xaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Background="#1E2530" BorderBrush="#2F3846" BorderThickness="1"
        CornerRadius="9" Padding="14,10" Margin="0,8,0,0" MaxWidth="420" HorizontalAlignment="Right">
  <Border.Effect><DropShadowEffect BlurRadius="18" ShadowDepth="3" Opacity="0.45" Color="Black"/></Border.Effect>
  <StackPanel Orientation="Horizontal">
    <TextBlock Name="icon" Style="{StaticResource Glyph}" FontSize="15" Margin="0,0,10,0"/>
    <TextBlock Name="text" TextWrapping="Wrap" MaxWidth="360" Foreground="#E4E8EF" VerticalAlignment="Center"/>
  </StackPanel>
</Border>
'@
        $toast = New-HTUiElement $xaml
        $icon = $toast.FindName('icon')
        $icon.Text = Get-HTGlyph $toneDef.Icon
        $icon.Foreground = Get-HTBrush $toneDef.Fore
        $toast.FindName('text').Text = $Text
        while ($toastHost.Children.Count -ge 4) { $toastHost.Children.RemoveAt(0) }
        [void]$toastHost.Children.Add($toast)
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds([Math]::Max(2, $Seconds))
        $script:ToastTimers[$timer] = $toast
        $timer.add_Tick({
                param($s, $e)
                $s.Stop()
                $t = $null
                if ($script:ToastTimers.TryGetValue($s, [ref]$t)) {
                    [void]$script:ToastTimers.Remove($s)
                    $h = $script:UI.Controls['toastHost']
                    if ($h -and $h.Children.Contains($t)) { $h.Children.Remove($t) }
                }
            })
        $timer.Start()
    }
    catch { Write-Verbose "Toast: $_" }
}

function Set-HTClipboard {
    # Kopiuje tekst do schowka. -Secret: wartość poufna - schowek jest czyszczony po 60 s (jeśli nadal ją zawiera)
    param([AllowEmptyString()][AllowNull()][string]$Text, [switch]$Secret)
    if ([string]::IsNullOrEmpty($Text)) {
        Write-Log -Message 'Brak treści do skopiowania.' -Type 'Warn'
        return
    }
    for ($i = 0; $i -lt 3; $i++) {
        try { [System.Windows.Clipboard]::SetText($Text); break }
        catch { Start-Sleep -Milliseconds 80 }
    }
    if (-not $Secret) { return }
    $script:Clipboard.Secret = $Text
    if (-not $script:Clipboard.Timer) {
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(60)
        $t.add_Tick({
                param($s, $e)
                $s.Stop()
                try {
                    if ($script:Clipboard.Secret -and [System.Windows.Clipboard]::ContainsText() -and [System.Windows.Clipboard]::GetText() -eq $script:Clipboard.Secret) {
                        [System.Windows.Clipboard]::Clear()
                    }
                }
                catch { Write-Verbose "Schowek: $_" }
                $script:Clipboard.Secret = $null
            })
        $script:Clipboard.Timer = $t
    }
    $script:Clipboard.Timer.Stop()
    $script:Clipboard.Timer.Start()
}
#endregion

#region Dziennik operacji (panel na dole okna)
function Add-HTLogItem {
    # Odbiorca wpisów Write-Log: lista w panelu dziennika, licznik nieprzeczytanych ostrzeżeń i powiadomienia
    param([Parameter(Mandatory)][object]$Entry)
    try {
        $items = $script:UI.LogItems
        if ($items.Count -ge 3000) { for ($i = 0; $i -lt 500; $i++) { $items.RemoveAt(0) } }
        $level = switch ($Entry.Type) { 'Warn' { 'WARN' } 'Error' { 'ERROR' } default { if ($Entry.Notify) { 'OK' } else { 'INFO' } } }
        $message = ($Entry.Message -replace '^(ℹ️|⚠️|❌)\s*', '')
        $item = [PSCustomObject]@{
            Time    = $Entry.Time.ToString('HH:mm:ss')
            Level   = $level
            Module  = $(if ($script:UI.ActiveModule) { [string]$script:UI.ActiveModule.Title } else { '' })
            Message = $message
        }
        $items.Add($item)
        $list = $script:UI.Controls['logList']
        if ($list -and $list.IsVisible) { $list.ScrollIntoView($item) }
        if (-not $script:UI.LogVisible -and ($level -eq 'WARN' -or $level -eq 'ERROR')) {
            $script:UI.LogUnread++
            Update-HTLogBadge
        }
        if ($Entry.Notify) {
            $tone = switch ($level) { 'WARN' { 'warn' } 'ERROR' { 'crit' } default { 'ok' } }
            Show-HTToast -Text $message -Tone $tone
        }
    }
    catch { Write-Verbose "Dziennik: $_" }
}

function Update-HTLogBadge {
    $badge = $script:UI.Controls['logBadge']
    if (-not $badge) { return }
    if ($script:UI.LogUnread -gt 0) {
        $script:UI.Controls['logBadgeText'].Text = [string][Math]::Min(99, $script:UI.LogUnread)
        $badge.Visibility = 'Visible'
    }
    else { $badge.Visibility = 'Collapsed' }
}

function Set-HTLogVisible {
    param([bool]$Visible)
    $c = $script:UI.Controls
    if (-not $c['logPanel']) { return }
    $script:UI.LogVisible = $Visible
    if ($Visible) {
        $c.logPanel.Visibility = 'Visible'
        $c.logSplitter.Visibility = 'Visible'
        $c.logRow.Height = New-Object System.Windows.GridLength 200
        $script:UI.LogUnread = 0
        Update-HTLogBadge
        if ($script:UI.LogItems.Count -gt 0) { $c.logList.ScrollIntoView($script:UI.LogItems[$script:UI.LogItems.Count - 1]) }
    }
    else {
        $c.logPanel.Visibility = 'Collapsed'
        $c.logSplitter.Visibility = 'Collapsed'
        $c.logRow.Height = New-Object System.Windows.GridLength 0
    }
}
#endregion

#region Stan aplikacji: pasek stanu, zajętość, połączenia
function Set-HTStatus {
    param([AllowEmptyString()][string]$Text)
    $label = $script:UI.Controls['txtStatus']
    if ($label) { $label.Text = $Text }
}

function Set-HTBusy {
    # Tryb "zajęty": kursor, wskaźnik postępu, blokada przycisków modułu i połączeń
    param([bool]$Busy, [string]$Text)
    if ($Busy) { $script:UI.BusyDepth++ } else { $script:UI.BusyDepth = [Math]::Max(0, $script:UI.BusyDepth - 1) }
    $c = $script:UI.Controls
    if (-not $script:UI.Window) { return }
    $isBusy = $script:UI.BusyDepth -gt 0
    if ($Text) { Set-HTStatus -Text $Text }
    if ($c['statusDot']) { $c.statusDot.Fill = Get-HTBrush $(if ($isBusy) { '#4C7DF0' } else { '#5EE3AE' }) }
    if ($c['prgStatus']) {
        $c.prgStatus.IsIndeterminate = $isBusy
        $c.prgStatus.Visibility = if ($isBusy) { 'Visible' } else { 'Collapsed' }
    }
    $script:UI.Window.Cursor = if ($isBusy) { [System.Windows.Input.Cursors]::Wait } else { $null }
    if (($Busy -and $script:UI.BusyDepth -eq 1) -or -not $isBusy) { Set-ButtonsState -Action $(if ($isBusy) { 'Lock' } else { 'Unlock' }) }
    $m = $script:UI.ActiveModule
    if ($m -and $m.View_['busyChip']) {
        $m.View_.busyChip.Visibility = if ($isBusy) { 'Visible' } else { 'Collapsed' }
        if ($isBusy -and $Text) { $m.View_.busyText.Text = $Text }
    }
    Update-HTUi
}

function Set-HTProgress {
    param([int]$Value, [int]$Maximum, [string]$Text)
    $bar = $script:UI.Controls['prgStatus']
    if ($bar) {
        $bar.IsIndeterminate = $false
        $bar.Maximum = [Math]::Max(1, $Maximum)
        $bar.Value = [Math]::Min($bar.Maximum, [Math]::Max(0, $Value))
        $bar.Visibility = 'Visible'
    }
    if ($Text) {
        Set-HTStatus -Text $Text
        $m = $script:UI.ActiveModule
        if ($m -and $m.View_['busyText']) { $m.View_.busyText.Text = $Text }
    }
    Update-HTUi
}

function Set-ButtonsState {
    # Blokada przycisków akcji aktywnego modułu i przycisków połączeń na czas operacji
    param([Parameter(Mandatory)][ValidateSet("Lock", "Unlock")][string]$Action)
    $enabled = ($Action -eq 'Unlock')
    foreach ($b in $script:UI.ConnectButtons.Values) { if ($b) { $b.IsEnabled = $enabled } }
    foreach ($m in $script:UI.Modules.Values) {
        foreach ($b in @($m.Buttons)) { $b.IsEnabled = $enabled }
    }
    foreach ($p in $script:UI.Panels.Values) {
        foreach ($b in @($p.Buttons)) { $b.IsEnabled = $enabled }
    }
}

function Invoke-HTAction {
    # Wykonuje akcję z obsługą błędów, dziennikiem i wskaźnikiem zajętości; zwraca wynik akcji
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string[]]$RequiredService,
        [switch]$NoBusy
    )
    foreach ($service in $RequiredService) {
        if (-not (Assert-HTConnection -Service $service)) { return }
    }
    if (-not $NoBusy) { Set-HTBusy -Busy $true -Text "$Name…" }
    try {
        & $ScriptBlock
    }
    catch {
        $message = $_.Exception.Message
        Write-Log -Message "$Name - błąd: $message" -Type "Error"
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text "Błąd: $Name" }
        $NoBusy = $true
        Show-HTError -Text $Name -ErrorObject $message
    }
    finally {
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text 'Gotowe' }
    }
}

function Invoke-HTForEach {
    # Wykonuje operację dla wielu elementów i zbiera błędy; zwraca liczbę udanych operacji
    param (
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][scriptblock]$Describe
    )
    $errors = @()
    $ok = 0
    foreach ($item in $Items) {
        try {
            & $Action $item | Out-Null
            $ok++
        }
        catch {
            $errors += "$(& $Describe $item): $($_.Exception.Message)"
        }
    }
    if ($errors.Count -gt 0) {
        Write-Log -Message "Część operacji zakończyła się błędem: $($errors -join ' | ')" -Type "Warn"
        Show-HTWarning -Text "Wykonano: $ok, błędy: $($errors.Count)`n`n$($errors -join "`n")" -Title 'Wynik operacji'
    }
    return $ok
}

function Test-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)
    switch ($Service) {
        "Exchange" { return [bool]$Global:ConnectedToExchange }
        "Graph" { return [bool]$Global:ConnectedToGraphAPI }
        "SharePoint" { return [bool]$Global:ConnectedToSharepointPnP }
        "AD" { return [bool]$Global:IsModuleActiveDirectoryLoaded }
    }
}

function Assert-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)
    if (Test-HTConnection -Service $Service) { return $true }
    $message = switch ($Service) {
        "Exchange" { "Ta operacja wymaga połączenia z Exchange Online.`nKliknij 'Exchange' w prawym górnym rogu okna." }
        "Graph" { "Ta operacja wymaga połączenia z Microsoft Graph.`nKliknij 'Microsoft 365' w prawym górnym rogu okna." }
        "SharePoint" { "Ta operacja wymaga połączenia z witryną SharePoint (PnP).`nKliknij 'SharePoint' w prawym górnym rogu okna." }
        "AD" { "Moduł ActiveDirectory (RSAT) nie jest dostępny na tym komputerze." }
    }
    Write-Log -Message "Brak połączenia: $Service" -Type "Warn"
    Show-HTWarning -Text $message -Title 'Brak połączenia'
    return $false
}

function Update-ConnectionButtonText {
    # Stan połączenia w nagłówku (kropka + nazwa tenantu) i podpowiedź przycisku
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service, [string]$TenantName = $null)
    $c = $script:UI.Controls
    $dot = $c["dot$Service"]
    $sub = $c["sub$Service"]
    $button = $script:UI.ConnectButtons[$Service]
    $names = @{ Exchange = 'Exchange Online'; Graph = 'Microsoft 365 (Graph)'; SharePoint = 'SharePoint (PnP)'; AD = 'Active Directory' }
    if ($dot) { $dot.Fill = Get-HTBrush $(if ($TenantName) { $script:DotColors.ok } else { $script:DotColors.off }) }
    if ($sub) {
        $sub.Text = if ($TenantName) { $TenantName } else { 'niepołączono' }
        $sub.Foreground = Get-HTBrush $(if ($TenantName) { '#8791A5' } else { '#5E6779' })
    }
    if ($button) {
        $button.ToolTip = if ($TenantName) { "$($names[$Service]): połączono ($TenantName). Kliknij, aby rozłączyć." } else { "$($names[$Service]): kliknij, aby połączyć." }
    }
}

function Invoke-HTInteractiveLogin {
    <#
        Logowanie interaktywne (MSAL / WAM / przeglądarka) bywa otwierane za oknem programu, bo okno logowania
        ma za rodzica konsolę PowerShell. Na czas logowania okno główne jest minimalizowane, a po nim przywracane
        i aktywowane - okno logowania zawsze jest widoczne na wierzchu.
    #>
    param([Parameter(Mandatory)][scriptblock]$ScriptBlock, [string]$Service = '')
    $w = $script:UI.Window
    $previousState = $null
    if ($w -and $w.IsVisible) {
        $previousState = $w.WindowState
        $w.Topmost = $false
        $w.WindowState = 'Minimized'
        Update-HTUi
    }
    try {
        & $ScriptBlock
    }
    finally {
        if ($w -and $null -ne $previousState) {
            $w.WindowState = if ($previousState -eq 'Minimized') { 'Normal' } else { $previousState }
            [void]$w.Activate()
            $w.Topmost = $true
            $w.Topmost = $false
            [void]$w.Focus()
            Update-HTUi
        }
    }
}
#endregion

#region Obsługa zdarzeń kontrolek modułów (wspólny dyspozytor)
# Akcja dostaje kontekst modułu ($m) i kontrolkę źródłową - niezależnie od miejsca, w którym została zdefiniowana.
$script:Handlers = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:Dispatchers = @{
    Click            = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Click' }
    TextChanged      = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'TextChanged' }
    Checked          = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Checked' }
    Unchecked        = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'Unchecked' }
    SelectionChanged = { param($s, $e) Invoke-HTControlHandler -Source $s -EventName 'SelectionChanged' }
}

function Register-HTControlHandler {
    param($Control, [string]$EventName, [hashtable]$Module, [scriptblock]$Action)
    $entry = $null
    if (-not $script:Handlers.TryGetValue($Control, [ref]$entry)) {
        $entry = @{ Module = $Module }
        $script:Handlers[$Control] = $entry
    }
    $entry.Module = $Module
    $isNew = -not $entry.ContainsKey($EventName)
    $entry[$EventName] = $Action
    if ($isNew) { $Control."add_$EventName"($script:Dispatchers[$EventName]) }
}

function Invoke-HTControlHandler {
    param($Source, [string]$EventName)
    try {
        $entry = $null
        if (-not $script:Handlers.TryGetValue($Source, [ref]$entry)) { return }
        $action = $entry[$EventName]
        if ($action) { Invoke-HTUiAction -Module $entry.Module -Action $action -Source $Source }
    }
    catch {
        Write-Log -Message "Błąd obsługi zdarzenia: $($_.Exception.Message)" -Type 'Error'
    }
}

function Invoke-HTUiAction {
    param([hashtable]$Module, [scriptblock]$Action, $Source = $null)
    try {
        $null = & $Action $Module $Source
    }
    catch {
        Write-Log -Message "Błąd: $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Operacja nie powiodła się.' $_
    }
}
#endregion

#region Przestrzenie robocze i moduły
function Register-HTWorkspace {
    <#
        Przestrzeń robocza = przycisk na górnym pasku + lista obiektów po lewej (-Panel) + własna nawigacja modułów.
        -Panel: klucz panelu obiektów (New-HTTargetPanel) albo pusty (bez listy).
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Icon = 'E80F',
        [string]$Panel = '',
        [string]$Description = '',
        [string[]]$Categories = @(),
        [string]$Service = ''
    )
    $script:UI.Workspaces[$Key] = @{
        Key = $Key; Title = $Title; Icon = $Icon; Panel = $Panel; Description = $Description; Categories = @($Categories)
        Service = $Service; NavHost = $null; Tab = $null; NavItems = @{}; LastModule = ''
    }
}

function Register-HTModule {
    <#
        Moduł = pozycja w nawigacji przestrzeni roboczej, w kategorii -Category.
        -Build { param($m) } buduje panel parametrów i przyciski akcji (przy pierwszym otwarciu).
        Kontrolki potrzebne w akcjach zapisuj w $m.C (np. $m.C.Days = Add-HTNumeric ...), bo akcje
        wykonują się później - lokalne zmienne bloku Build już wtedy nie istnieją.
    #>
    param(
        [Parameter(Mandatory)][string]$Workspace,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Icon = 'E74C',
        [string]$Description = '',
        [string]$Service = '',
        [Parameter(Mandatory)][scriptblock]$Build
    )
    $definition = @{ Workspace = $Workspace; Category = $Category; Key = $Key; Title = $Title; Icon = $Icon; Description = $Description; Service = $Service; Build = $Build }
    for ($i = 0; $i -lt $script:UI.ModuleDefs.Count; $i++) {
        if ($script:UI.ModuleDefs[$i].Key -eq $Key) { $script:UI.ModuleDefs[$i] = $definition; return }
    }
    [void]$script:UI.ModuleDefs.Add($definition)
}

function Get-HTModuleDefinition([string]$Key) {
    foreach ($d in $script:UI.ModuleDefs) { if ($d.Key -eq $Key) { return $d } }
    return $null
}

$script:NavEvents = @{
    WorkspaceClick = {
        param($s, $e)
        try { Show-HTWorkspace -Key ([string]$s.Tag) }
        catch { Write-Log -Message "Błąd przełączania przestrzeni: $($_.Exception.Message)" -Type 'Error' }
    }
    ModuleClick    = {
        param($s, $e)
        try { Show-HTModule -Key ([string]$s.Tag) }
        catch {
            Write-Log -Message "Błąd otwierania modułu: $($_.Exception.Message)" -Type 'Error'
            Show-HTError 'Nie można otworzyć modułu.' $_
        }
    }
}

function Initialize-HTNavigation {
    # Przyciski przestrzeni roboczych i nawigacja modułów (kategorie w kolejności rejestracji)
    $c = $script:UI.Controls
    $c.wsSwitcher.Children.Clear()
    $c.navHost.Children.Clear()
    $i = 0
    foreach ($ws in $script:UI.Workspaces.Values) {
        $i++
        $tab = New-Object System.Windows.Controls.RadioButton
        $tab.Style = Get-HTThemeResource 'WorkspaceTab'
        $tab.GroupName = 'workspaces'
        $tab.Content = New-HTIconContent -Text $ws.Title -Icon $ws.Icon
        $tab.Tag = $ws.Key
        $tab.ToolTip = "$($ws.Title): $($ws.Description) (Ctrl+$i)"
        $tab.add_Click($script:NavEvents.WorkspaceClick)
        [void]$c.wsSwitcher.Children.Add($tab)
        $ws.Tab = $tab

        $panel = New-Object System.Windows.Controls.StackPanel
        $panel.Visibility = 'Collapsed'
        $ws.NavHost = $panel
        $ws.NavItems = @{}
        [void]$c.navHost.Children.Add($panel)
        $defs = @($script:UI.ModuleDefs | Where-Object { $_.Workspace -eq $ws.Key })
        $categories = New-Object System.Collections.ArrayList
        foreach ($order in @($ws.Categories)) { if ($order -and @($defs | Where-Object { $_.Category -eq $order }).Count -gt 0) { [void]$categories.Add($order) } }
        foreach ($d in $defs) { if (-not $categories.Contains($d.Category)) { [void]$categories.Add($d.Category) } }
        foreach ($cat in $categories) {
            $header = New-Object System.Windows.Controls.TextBlock
            $header.Style = Get-HTThemeResource 'NavHeader'
            $header.Text = $cat.ToUpperInvariant()
            [void]$panel.Children.Add($header)
            foreach ($d in @($defs | Where-Object { $_.Category -eq $cat })) {
                $item = New-HTNavItem -Definition $d -Workspace $ws.Key
                $ws.NavItems[$d.Key] = $item
                [void]$panel.Children.Add($item)
            }
        }
    }
}

function New-HTNavItem {
    param([hashtable]$Definition, [string]$Workspace)
    $rb = New-Object System.Windows.Controls.RadioButton
    $rb.Style = Get-HTThemeResource 'NavItem'
    $rb.GroupName = "nav_$Workspace"
    $rb.Tag = $Definition.Key
    if ($Definition.Description) { $rb.ToolTip = $Definition.Description }
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($width in @('Auto', '*')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = if ($width -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        [void]$grid.ColumnDefinitions.Add($cd)
    }
    $icon = New-HTGlyphBlock -Code $Definition.Icon -Size 14
    $icon.Margin = '2,0,11,0'
    $icon.Width = 18
    [void]$grid.Children.Add($icon)
    $text = New-Object System.Windows.Controls.TextBlock
    $text.Text = $Definition.Title
    $text.TextTrimming = 'CharacterEllipsis'
    $text.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    [void]$grid.Children.Add($text)
    $rb.Content = $grid
    $rb.add_Click($script:NavEvents.ModuleClick)
    return $rb
}

function Show-HTWorkspace {
    param([string]$Key, [string]$ModuleKey = '')
    if (-not $script:UI.Workspaces.Contains($Key)) { $Key = @($script:UI.Workspaces.Keys)[0] }
    $ws = $script:UI.Workspaces[$Key]
    $previous = $script:UI.ActiveWorkspace
    $script:UI.ActiveWorkspace = $Key
    foreach ($other in $script:UI.Workspaces.Values) {
        if ($other.NavHost) { $other.NavHost.Visibility = if ($other.Key -eq $Key) { 'Visible' } else { 'Collapsed' } }
        if ($other.Tab -and $other.Key -eq $Key -and $other.Tab.IsChecked -ne $true) { $other.Tab.IsChecked = $true }
    }
    $c = $script:UI.Controls
    foreach ($p in $script:UI.Panels.Values) { $p.Root.Visibility = if ($p.Key -eq $ws.Panel) { 'Visible' } else { 'Collapsed' } }
    $c.targetColumn.Width = if ($ws.Panel) { New-Object System.Windows.GridLength 320 } else { New-Object System.Windows.GridLength 0 }
    $c.txtSubtitle.Text = $ws.Description
    if ($previous -and $previous -ne $Key) { Write-Log -Message "Przestrzeń robocza: $($ws.Title)" -Type 'Info' }
    if (-not $ModuleKey) { $ModuleKey = $ws.LastModule }
    $def = Get-HTModuleDefinition $ModuleKey
    if (-not $def -or $def.Workspace -ne $Key) {
        $def = $null
        foreach ($d in $script:UI.ModuleDefs) { if ($d.Workspace -eq $Key) { $def = $d; break } }
    }
    if ($def) { Show-HTModule -Key $def.Key }
    elseif ($script:UI.ActiveModule) { $script:UI.ActiveModule.Root.Visibility = 'Collapsed'; $script:UI.ActiveModule = $null }
    # Pierwsze otwarcie przestrzeni: pusta lista obiektów wczytuje się sama, gdy usługa jest dostępna
    $panel = if ($ws.Panel) { $script:UI.Panels[$ws.Panel] } else { $null }
    if ($panel -and $panel.Loader -and -not $panel.AutoTried -and $script:UI.BusyDepth -eq 0) {
        $empty = if ($panel.IsTree) { $panel.pTree.Items.Count -eq 0 } else { $panel.Table.Rows.Count -eq 0 }
        if ($empty -and (-not $panel.Service -or (Test-HTConnection -Service $panel.Service))) {
            $panel.AutoTried = $true
            Invoke-HTPanelLoad -Panel $panel -Quiet
        }
    }
}

function Show-HTModule {
    param([string]$Key)
    $definition = Get-HTModuleDefinition $Key
    if (-not $definition) { return }
    if ($script:UI.ActiveWorkspace -ne $definition.Workspace) { Show-HTWorkspace -Key $definition.Workspace -ModuleKey $Key; return }
    $m = $script:UI.Modules[$Key]
    if (-not $m) { $m = Initialize-HTModule -Definition $definition }
    $active = $script:UI.ActiveModule
    if ($active -and -not [object]::ReferenceEquals($active, $m)) { $active.Root.Visibility = 'Collapsed' }
    $m.Root.Visibility = 'Visible'
    $script:UI.ActiveModule = $m
    $ws = $script:UI.Workspaces[$definition.Workspace]
    $ws.LastModule = $Key
    $nav = $ws.NavItems[$Key]
    if ($nav -and $nav.IsChecked -ne $true) { $nav.IsChecked = $true }
    if ($m.OnShow) { Invoke-HTUiAction -Module $m -Action $m.OnShow }
}

function New-HTModuleContext {
    param([hashtable]$Definition)
    $ws = $script:UI.Workspaces[$Definition.Workspace]
    return @{
        Key            = $Definition.Key
        Title          = $Definition.Title
        Description    = $Definition.Description
        Category       = $Definition.Category
        Icon           = $Definition.Icon
        Workspace      = $Definition.Workspace
        WorkspaceTitle = $(if ($ws) { $ws.Title } else { '' })
        Panel          = $(if ($ws) { $ws.Panel } else { '' })
        Service        = $(if ($Definition.Service) { $Definition.Service } elseif ($ws) { $ws.Service } else { '' })
        Buttons        = New-Object System.Collections.ArrayList
        PrimaryButton  = $null
        RowActions     = New-Object System.Collections.ArrayList
        RowDoubleClick = $null
        OnShow         = $null
        SecretColumns  = @()
        HiddenColumns  = @()
        ColorBools     = $false
        GoodWhenNo     = @()
        RevealSecrets  = $false
        Stats          = @{}
        EmptyText      = ''
        EmptyHint      = ''
        ResultHint     = ''
        C              = @{}
        Data           = @{}
        View_          = @{}
        ColumnIndex    = @{}
        Root           = $null
        ParamsCard     = $null
        ParamsStack    = $null
        StatsGrid      = $null
        Grid           = $null
        Table          = $null
        View           = $null
        FilterBox      = $null
        Objects        = New-Object System.Collections.ArrayList
    }
}

function Initialize-HTModule {
    param([hashtable]$Definition)
    $m = New-HTModuleContext -Definition $Definition
    $script:UI.Modules[$Definition.Key] = $m
    New-HTModuleView -Module $m
    try { $null = & $Definition.Build $m }
    catch {
        Write-Log -Message "Nie udało się zbudować modułu '$($m.Title)': $($_.Exception.Message)" -Type 'Error'
        Add-HTLabel -Parent (Add-HTToolbarRow -Module $m) -Text "Błąd modułu: $($_.Exception.Message)" | Out-Null
    }
    Complete-HTModuleView -Module $m
    $m.Root.Visibility = 'Collapsed'
    [void]$script:UI.Controls['contentHost'].Children.Add($m.Root)
    return $m
}

function Get-HTActiveModule { return $script:UI.ActiveModule }
#endregion

#region Lista obiektów (lewy panel): zaznaczanie, wyszukiwanie, wczytywanie z listy
$script:TargetPanelXaml = @'
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="#12171D" BorderBrush="#1E242E" BorderThickness="0,0,1,0">
  <Grid Margin="14,14,12,10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <Grid Margin="2,0,0,10">
      <TextBlock x:Name="pTitle" Foreground="#8791A5" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
      <Border Style="{StaticResource Chip}" HorizontalAlignment="Right" Margin="0">
        <TextBlock x:Name="pCount" Text="0" Foreground="#AEB6C4" FontSize="11"/>
      </Border>
    </Grid>
    <Border Grid.Row="1" Style="{StaticResource Card}" Padding="12,12,12,6" Margin="0,0,0,10">
      <StackPanel x:Name="pSource"/>
    </Border>
    <TextBox x:Name="pSearch" Grid.Row="2" Margin="0,0,0,8"/>
    <Grid Grid.Row="3">
      <ListBox x:Name="pList" SelectionMode="Extended">
        <ListBox.ItemTemplate>
          <DataTemplate>
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <CheckBox IsChecked="{Binding [Sel], Mode=OneWay}" Margin="0,0,10,0" VerticalAlignment="Center" Focusable="False"/>
              <Ellipse Grid.Column="1" Width="8" Height="8" Fill="{Binding [Dot]}" Margin="0,0,10,0" VerticalAlignment="Center"/>
              <StackPanel Grid.Column="2">
                <TextBlock Text="{Binding [Title]}" FontWeight="SemiBold" TextTrimming="CharacterEllipsis"/>
                <TextBlock Text="{Binding [Sub]}" Foreground="#7B8496" FontSize="11.5" TextTrimming="CharacterEllipsis"/>
              </StackPanel>
            </Grid>
          </DataTemplate>
        </ListBox.ItemTemplate>
      </ListBox>
      <TreeView x:Name="pTree" Visibility="Collapsed" BorderThickness="0" Background="Transparent" Padding="0"/>
      <StackPanel x:Name="pEmpty" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False" Margin="10">
        <TextBlock x:Name="pEmptyIcon" Style="{StaticResource Glyph}" FontSize="28" Foreground="#3A4352" HorizontalAlignment="Center"/>
        <TextBlock x:Name="pEmptyText" Foreground="#5E6779" TextAlignment="Center" TextWrapping="Wrap" Margin="0,10,0,0"/>
      </StackPanel>
    </Grid>
    <Grid Grid.Row="4" Margin="0,8,0,0">
      <StackPanel x:Name="pSelButtons" Orientation="Horizontal">
        <Button x:Name="pAll" Style="{StaticResource GhostButton}" ToolTip="Zaznacz widoczne"/>
        <Button x:Name="pNone" Style="{StaticResource GhostButton}" ToolTip="Odznacz wszystkie"/>
        <Button x:Name="pInvert" Style="{StaticResource GhostButton}" ToolTip="Odwróć zaznaczenie widocznych"/>
        <Button x:Name="pPaste" Style="{StaticResource GhostButton}" ToolTip="Zaznacz obiekty z listy (wklej lub wczytaj z pliku CSV/TXT)"/>
      </StackPanel>
      <TextBlock x:Name="pSel" HorizontalAlignment="Right" VerticalAlignment="Center" Foreground="#8791A5" FontSize="12"/>
    </Grid>
  </Grid>
</Border>
'@

$script:TargetPanels = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:TargetEvents = @{
    ItemClick     = {
        param($s, $e)
        try {
            $cb = $e.OriginalSource
            if (-not ($cb -is [System.Windows.Controls.CheckBox])) { return }
            $drv = $cb.DataContext
            if (-not ($drv -is [System.Data.DataRowView])) { return }
            $p = $script:TargetPanels[$s]
            $value = ($cb.IsChecked -eq $true)
            # Kliknięcie pola w jednym z kilku zaznaczonych wierszy zmienia je wszystkie
            $rows = @($s.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] })
            if ($rows.Count -gt 1 -and $rows -contains $drv) { foreach ($r in $rows) { $r.Row['Sel'] = $value } }
            else { $drv.Row['Sel'] = $value }
            Update-HTTargetCount $p
        }
        catch { Write-Log -Message "Błąd zaznaczania: $($_.Exception.Message)" -Type 'Error' }
    }
    KeyDown       = {
        param($s, $e)
        try {
            if ($e.Key -ne [System.Windows.Input.Key]::Space) { return }
            $p = $script:TargetPanels[$s]
            $rows = @($s.SelectedItems | Where-Object { $_ -is [System.Data.DataRowView] })
            if ($rows.Count -eq 0) { return }
            $value = -not [bool]$rows[0].Row['Sel']
            foreach ($r in $rows) { $r.Row['Sel'] = $value }
            Update-HTTargetCount $p
            $e.Handled = $true
        }
        catch { Write-Verbose $_ }
    }
    SelectionChanged = {
        param($s, $e)
        try {
            $p = $script:TargetPanels[$s]
            Update-HTTargetCount $p
            $m = $script:UI.ActiveModule
            if ($m -and $m.OnTargetChange) { Invoke-HTUiAction -Module $m -Action $m.OnTargetChange }
        }
        catch { Write-Verbose $_ }
    }
    SearchChanged = {
        param($s, $e)
        try { Update-HTTargetFilter $script:TargetPanels[$s] } catch { Write-Verbose $_ }
    }
    ButtonClick   = {
        param($s, $e)
        try {
            $p = $script:TargetPanels[$s]
            $mode = [string]$s.Tag
            if ($mode -eq 'Paste') { Select-HTTargetsFromList -Panel $p }
            else { Set-HTTargetCheck -Panel $p -Mode $mode }
        }
        catch { Show-HTError 'Nie można zaznaczyć obiektów.' $_ }
    }
}

function New-HTTargetPanel {
    <#
        Lista obiektów (lewy panel): -Key, -Title, -Placeholder, -EmptyIcon, -EmptyText.
        Obiekty wczytuje Set-HTTargetItems; -Describe { param($o) @{ Key; Title; Sub; Dot; Search } } opisuje wiersz.
        -Tree: zamiast listy drzewo (np. biblioteki i foldery SharePoint).
    #>
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Title,
        [string]$Placeholder = 'Szukaj…',
        [string]$EmptyIcon = 'E721',
        [string]$EmptyText = 'Lista jest pusta - kliknij «Wczytaj».',
        [scriptblock]$Describe,
        [switch]$Tree
    )
    $root = New-HTUiElement $script:TargetPanelXaml
    $p = @{ Key = $Key; Root = $root; EmptyText = $EmptyText; Describe = $Describe; Objects = @{}; Buttons = New-Object System.Collections.ArrayList; IsTree = [bool]$Tree }
    foreach ($n in 'pTitle', 'pCount', 'pSource', 'pSearch', 'pList', 'pTree', 'pEmpty', 'pEmptyIcon', 'pEmptyText', 'pAll', 'pNone', 'pInvert', 'pPaste', 'pSel', 'pSelButtons') { $p[$n] = $root.FindName($n) }
    $p.pTitle.Text = $Title.ToUpperInvariant()
    $p.pSearch.Tag = $Placeholder
    $p.pEmptyIcon.Text = Get-HTGlyph $EmptyIcon
    $p.pEmptyText.Text = $EmptyText
    $p.pAll.Content = New-HTIconContent -Text '' -Icon 'E8B3' -IconSize 13
    $p.pNone.Content = New-HTIconContent -Text '' -Icon 'E894' -IconSize 13
    $p.pInvert.Content = New-HTIconContent -Text '' -Icon 'E8AB' -IconSize 13
    $p.pPaste.Content = New-HTIconContent -Text '' -Icon 'E8FD' -IconSize 13

    $t = New-Object System.Data.DataTable $Key
    [void]$t.Columns.Add('Sel', [bool])
    foreach ($c in 'Key', 'Title', 'Sub', 'Dot', 'Search') { [void]$t.Columns.Add($c, [string]) }
    $t.Columns['Sel'].DefaultValue = $false
    $t.Columns['Dot'].DefaultValue = $script:DotColors.unknown
    $t.PrimaryKey = [System.Data.DataColumn[]]@($t.Columns['Key'])
    $t.CaseSensitive = $false
    $view = [System.Data.DataView]::new($t)
    $view.Sort = 'Title ASC'
    $p.Table = $t
    $p.View = $view
    $p.pList.ItemsSource = $view

    $script:TargetPanels[$p.pList] = $p
    $script:TargetPanels[$p.pSearch] = $p
    $p.pList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$script:TargetEvents.ItemClick)
    $p.pList.add_PreviewKeyDown($script:TargetEvents.KeyDown)
    $p.pList.add_SelectionChanged($script:TargetEvents.SelectionChanged)
    $p.pSearch.add_TextChanged($script:TargetEvents.SearchChanged)
    foreach ($pair in @(@('pAll', 'CheckVisible'), @('pNone', 'UncheckAll'), @('pInvert', 'InvertVisible'), @('pPaste', 'Paste'))) {
        $script:TargetPanels[$p[$pair[0]]] = $p
        $p[$pair[0]].Tag = $pair[1]
        $p[$pair[0]].add_Click($script:TargetEvents.ButtonClick)
    }
    if ($Tree) {
        $p.pList.Visibility = 'Collapsed'
        $p.pTree.Visibility = 'Visible'
        $p.pSearch.Visibility = 'Collapsed'
        $p.pAll.Visibility = 'Collapsed'
        $p.pInvert.Visibility = 'Collapsed'
        $p.pPaste.Visibility = 'Collapsed'
        $script:TargetPanels[$p.pTree] = $p
        $script:TargetPanels[$p.pNone] = $p
    }
    $script:UI.Panels[$Key] = $p
    Update-HTTargetCount $p
    return $p
}

function Add-HTPanelButton {
    # Przycisk w karcie źródła panelu (np. «Wczytaj»); akcja dostaje panel: { param($p) }
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][string]$Text, [string]$Icon = '', [Parameter(Mandatory)][scriptblock]$OnClick, [switch]$Primary, [string]$ToolTip = '', $Parent = $null)
    $b = New-HTButton -Text $Text -Icon $Icon -Primary:$Primary -ToolTip $ToolTip
    $b.Margin = '0,0,8,6'
    $b.Tag = @{ Panel = $Panel; Action = $OnClick }
    $b.add_Click({
            param($s, $e)
            try { $null = & $s.Tag.Action $s.Tag.Panel }
            catch {
                Write-Log -Message "Błąd: $($_.Exception.Message)" -Type 'Error'
                Show-HTError 'Operacja nie powiodła się.' $_
            }
        })
    [void]$Panel.Buttons.Add($b)
    $target = if ($Parent) { $Parent } else {
        if (-not $Panel['SourceRow']) {
            $wrap = New-Object System.Windows.Controls.WrapPanel
            [void]$Panel.pSource.Children.Add($wrap)
            $Panel.SourceRow = $wrap
        }
        $Panel.SourceRow
    }
    [void]$target.Children.Add($b)
    return $b
}

function Add-HTPanelHint {
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][string]$Text)
    $t = New-HTDialogText -Text $Text -Color '#7B8496' -Size 11.5
    $t.Margin = '0,0,0,6'
    [void]$Panel.pSource.Children.Add($t)
    return $t
}

function Set-HTTargetItems {
    # Wczytuje obiekty do listy (zachowuje zaznaczenia obiektów o tym samym kluczu)
    param([Parameter(Mandatory)][hashtable]$Panel, [AllowEmptyCollection()][object[]]$Items)
    $t = $Panel.Table
    $checked = @{}
    foreach ($r in $t.Select('Sel = true')) { $checked[[string]$r['Key']] = $true }
    $Panel.Objects = @{}
    $t.BeginLoadData()
    try {
        $t.Rows.Clear()
        foreach ($o in @($Items)) {
            if ($null -eq $o) { continue }
            $d = & $Panel.Describe $o
            $k = [string]$d.Key
            if (-not $k -or $Panel.Objects.ContainsKey($k)) { continue }
            $Panel.Objects[$k] = $o
            $row = $t.NewRow()
            $row['Key'] = $k
            $row['Title'] = [string]$d.Title
            $row['Sub'] = [string]$d.Sub
            $row['Dot'] = $(if ($d.Dot) { if ($script:DotColors.ContainsKey([string]$d.Dot)) { $script:DotColors[[string]$d.Dot] } else { [string]$d.Dot } } else { $script:DotColors.unknown })
            $row['Search'] = ("$($d.Title) $($d.Sub) $($d.Search)").ToLowerInvariant()
            $row['Sel'] = $checked.ContainsKey($k)
            $t.Rows.Add($row)
        }
    }
    finally { $t.EndLoadData() }
    Update-HTTargetFilter $Panel
}

function Update-HTTargetItem {
    # Odświeża opis jednego obiektu po zmianie (np. konto zablokowane)
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][object]$Item)
    $d = & $Panel.Describe $Item
    $row = $Panel.Table.Rows.Find([string]$d.Key)
    if (-not $row) { return }
    $Panel.Objects[[string]$d.Key] = $Item
    $row['Title'] = [string]$d.Title
    $row['Sub'] = [string]$d.Sub
    $row['Dot'] = $(if ($d.Dot -and $script:DotColors.ContainsKey([string]$d.Dot)) { $script:DotColors[[string]$d.Dot] } elseif ($d.Dot) { [string]$d.Dot } else { $script:DotColors.unknown })
    $row['Search'] = ("$($d.Title) $($d.Sub) $($d.Search)").ToLowerInvariant()
}

function Remove-HTTargetItem {
    param([Parameter(Mandatory)][hashtable]$Panel, [Parameter(Mandatory)][object]$Item)
    $d = & $Panel.Describe $Item
    $row = $Panel.Table.Rows.Find([string]$d.Key)
    if ($row) { $Panel.Table.Rows.Remove($row) }
    [void]$Panel.Objects.Remove([string]$d.Key)
    Update-HTTargetCount $Panel
}

function Update-HTTargetCount {
    param([hashtable]$Panel)
    if (-not $Panel) { return }
    if ($Panel.IsTree) {
        $checked = @(Get-HTTreeChecked -Panel $Panel).Count
        $Panel.pCount.Text = [string]$Panel.pTree.Items.Count
        $Panel.pSel.Text = if ($checked -gt 0) { "zaznaczone: $checked" } else { '' }
        $Panel.pEmpty.Visibility = if ($Panel.pTree.Items.Count -gt 0) { 'Collapsed' } else { 'Visible' }
        return
    }
    $t = $Panel.Table
    $selected = @($t.Select('Sel = true')).Count
    $Panel.pCount.Text = [string]$t.Rows.Count
    $Panel.pSel.Text = if ($Panel.View.Count -ne $t.Rows.Count) { "zaznaczone: $selected • widoczne: $($Panel.View.Count)" } else { "zaznaczone: $selected z $($t.Rows.Count)" }
    $Panel.pSel.Foreground = Get-HTBrush $(if ($selected -gt 0) { '#8CB0FF' } else { '#7B8496' })
    if ($Panel.View.Count -gt 0) { $Panel.pEmpty.Visibility = 'Collapsed' }
    else {
        $Panel.pEmpty.Visibility = 'Visible'
        $Panel.pEmptyText.Text = if ($t.Rows.Count -gt 0) { 'Nic nie pasuje do wyszukiwania' } else { $Panel.EmptyText }
    }
}

function Update-HTTargetFilter {
    param([hashtable]$Panel)
    $text = $Panel.pSearch.Text.Trim().ToLowerInvariant()
    $terms = @($text -split '\s+' | Where-Object { $_ })
    $parts = foreach ($term in $terms) { "Search LIKE '*{0}*'" -f (ConvertTo-HTLikeLiteral $term) }
    try { $Panel.View.RowFilter = (@($parts) -join ' AND ') } catch { $Panel.View.RowFilter = '' }
    Update-HTTargetCount $Panel
}

function Set-HTTargetCheck {
    param([hashtable]$Panel, [ValidateSet('CheckVisible', 'UncheckAll', 'InvertVisible')][string]$Mode)
    if ($Panel.IsTree) {
        foreach ($node in @(Get-HTTreeNodes -Panel $Panel)) {
            $cb = if ($node.Header -is [System.Windows.Controls.Panel]) { $node.Header.Children[0] } else { $null }
            if ($cb -is [System.Windows.Controls.CheckBox]) { $cb.IsChecked = $false }
        }
        Update-HTTargetCount $Panel
        return
    }
    $t = $Panel.Table
    switch ($Mode) {
        'CheckVisible' { foreach ($drv in @($Panel.View | ForEach-Object { $_ })) { $drv.Row['Sel'] = $true } }
        'UncheckAll' { foreach ($r in $t.Rows) { if ([bool]$r['Sel']) { $r['Sel'] = $false } } }
        'InvertVisible' { foreach ($drv in @($Panel.View | ForEach-Object { $_ })) { $drv.Row['Sel'] = -not [bool]$drv.Row['Sel'] } }
    }
    Update-HTTargetCount $Panel
}

function Select-HTTargetsFromList {
    # Zaznacza obiekty wskazane listą (wklejoną lub z pliku): dopasowanie do tytułu, opisu i pól wyszukiwania
    param([Parameter(Mandatory)][hashtable]$Panel)
    if ($Panel.Table.Rows.Count -eq 0) { Show-HTWarning 'Najpierw wczytaj listę obiektów.'; return }
    $text = Show-InputBox -Title 'Zaznacz z listy' -Prompt 'Wklej identyfikatory (UPN, e-mail, login lub nazwę) - jeden w linii, albo zostaw puste i wczytaj plik CSV/TXT.' -Multiline -AllowEmpty -Icon 'E8FD'
    if ($null -eq $text) { return }
    $ids = @(Split-HTInputList -Text $text)
    if ($ids.Count -eq 0) {
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Title = 'Wczytaj identyfikatory'
        $dialog.Filter = 'CSV lub TXT (*.csv;*.txt)|*.csv;*.txt|Wszystkie pliki (*.*)|*.*'
        if ($dialog.ShowDialog() -ne $true) { return }
        $ids = @(Import-HTIdentityFile -Path $dialog.FileName)
    }
    if ($ids.Count -eq 0) { return }
    $found = 0
    $missing = New-Object System.Collections.Generic.List[string]
    foreach ($id in $ids) {
        $needle = $id.ToLowerInvariant()
        $match = $null
        foreach ($r in $Panel.Table.Rows) {
            $words = @(([string]$r['Search']) -split '\s+')
            if ([string]$r['Key'] -eq $id -or ([string]$r['Title']).ToLowerInvariant() -eq $needle -or $words -contains $needle) { $match = $r; break }
        }
        if ($match) { $match['Sel'] = $true; $found++ } else { $missing.Add($id) }
    }
    Update-HTTargetCount $Panel
    if ($missing.Count -gt 0) {
        Show-HTWarning -Title 'Zaznacz z listy' -Text ("Zaznaczono: $found z $($ids.Count).`nNie znaleziono na liście:`n" + (($missing | Select-Object -First 40) -join "`n"))
    }
    else { Show-HTToast "Zaznaczono obiektów: $found." 'ok' }
}

function Get-HTTargets {
    <#
        Obiekty docelowe modułu: zaznaczone polami wyboru, a gdy nic nie zaznaczono - podświetlone na liście.
        -Single: dokładnie jeden obiekt (pierwszy). Wyświetla ostrzeżenie, gdy lista jest pusta.
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$Single, [switch]$Quiet)
    $p = $script:UI.Panels[$Module.Panel]
    if (-not $p) { return @() }
    $result = @()
    if ($p.IsTree) {
        $result = @(Get-HTTreeChecked -Panel $p)
        if ($result.Count -eq 0 -and $p.pTree.SelectedItem) { $result = @($p.pTree.SelectedItem.Tag) }
    }
    else {
        $rows = @($p.Table.Select('Sel = true'))
        if ($rows.Count -eq 0) { $rows = @($p.pList.SelectedItems | ForEach-Object { $_.Row }) }
        $result = @($rows | ForEach-Object { $p.Objects[[string]$_['Key']] } | Where-Object { $null -ne $_ })
    }
    if ($result.Count -eq 0) {
        if (-not $Quiet) { Show-HTWarning 'Zaznacz obiekty na liście po lewej (pole wyboru) albo kliknij jeden z nich.' -Title 'Brak obiektów' }
        return @()
    }
    if ($Single) { return @($result[0]) }
    return $result
}

function Get-HTPanel([string]$Key) { return $script:UI.Panels[$Key] }

# Drzewo (SharePoint): węzły z polem wyboru; Tag węzła = obiekt
function New-HTTreeItem {
    param([Parameter(Mandatory)][object]$Item, [string]$Text, [string]$Icon = 'E8B7', [switch]$Lazy)
    $node = New-Object System.Windows.Controls.TreeViewItem
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Focusable = $false
    $cb.Margin = '0,0,8,0'
    [void]$sp.Children.Add($cb)
    $glyph = New-HTGlyphBlock -Code $Icon -Size 13 -Color '#8CB0FF'
    $glyph.Margin = '0,0,8,0'
    [void]$sp.Children.Add($glyph)
    $label = New-Object System.Windows.Controls.TextBlock
    $label.Text = $Text
    $label.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($label)
    $node.Header = $sp
    $node.Tag = $Item
    $node.ToolTip = [string]$Item.ServerRelativeUrl
    if ($Lazy) {
        $placeholder = New-Object System.Windows.Controls.TreeViewItem
        $placeholder.Header = 'Ładowanie…'
        $placeholder.Tag = '__placeholder__'
        [void]$node.Items.Add($placeholder)
    }
    return $node
}

function Get-HTTreeNodes {
    param([Parameter(Mandatory)][hashtable]$Panel)
    $stack = New-Object System.Collections.Stack
    foreach ($n in $Panel.pTree.Items) { $stack.Push($n) }
    while ($stack.Count -gt 0) {
        $n = $stack.Pop()
        if ($n.Tag -eq '__placeholder__') { continue }
        $n
        foreach ($child in $n.Items) { $stack.Push($child) }
    }
}

function Get-HTTreeChecked {
    param([Parameter(Mandatory)][hashtable]$Panel)
    foreach ($n in @(Get-HTTreeNodes -Panel $Panel)) {
        $cb = if ($n.Header -is [System.Windows.Controls.Panel]) { $n.Header.Children[0] } else { $null }
        if ($cb -is [System.Windows.Controls.CheckBox] -and $cb.IsChecked -eq $true) { $n.Tag }
    }
}
#endregion

#region Widok modułu: nagłówek, parametry, kafelki, tabela wyników z panelem szczegółów
$script:ModuleViewXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="Auto"/>
    <RowDefinition Height="*" MinHeight="160"/>
  </Grid.RowDefinitions>

  <Grid Margin="0,0,0,16">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <Border Width="44" Height="44" CornerRadius="11" Background="#1A2640" BorderBrush="#2F4478" BorderThickness="1" VerticalAlignment="Top">
      <TextBlock x:Name="hdrIcon" Style="{StaticResource Glyph}" FontSize="20" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
    </Border>
    <StackPanel Grid.Column="1" Margin="14,0,0,0" VerticalAlignment="Center">
      <StackPanel Orientation="Horizontal">
        <TextBlock x:Name="hdrTitle" FontSize="20" FontWeight="SemiBold" Foreground="White"/>
        <Border Style="{StaticResource Chip}" Margin="12,2,0,0">
          <TextBlock x:Name="hdrCategory" FontSize="11" Foreground="#8791A5"/>
        </Border>
      </StackPanel>
      <TextBlock x:Name="hdrDesc" Foreground="#8791A5" TextWrapping="Wrap" Margin="0,4,0,0" MaxWidth="1000" HorizontalAlignment="Left"/>
    </StackPanel>
    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Top">
      <Border x:Name="busyChip" Style="{StaticResource Chip}" Background="#1A2640" Padding="12,5" Visibility="Collapsed" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal">
          <Ellipse Width="8" Height="8" Fill="#4C7DF0" Margin="0,0,8,0" VerticalAlignment="Center"/>
          <TextBlock x:Name="busyText" Text="Trwa operacja…" Foreground="#8CC0FF" FontSize="12" VerticalAlignment="Center" MaxWidth="360" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </Border>
      <Button x:Name="btnCollapse" Style="{StaticResource GhostButton}" Padding="8,4" MinHeight="28" ToolTip="Zwiń / rozwiń panel parametrów"/>
    </StackPanel>
  </Grid>

  <Border x:Name="paramsCard" Grid.Row="1" Style="{StaticResource Card}" Padding="16,14,10,8" Margin="0,0,0,12" Visibility="Collapsed">
    <StackPanel x:Name="paramsStack"/>
  </Border>

  <UniformGrid x:Name="statsGrid" Grid.Row="2" Rows="1" Margin="0,0,-10,12" Visibility="Collapsed"/>

  <Grid Grid.Row="3" Margin="2,0,0,8">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="Wyniki" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/>
    <Border Grid.Column="1" Style="{StaticResource Chip}" Margin="10,0,0,0">
      <TextBlock x:Name="countText" Text="0" Foreground="#AEB6C4" FontSize="11.5"/>
    </Border>
    <TextBlock x:Name="resultHint" Grid.Column="2" Foreground="#5E6779" FontSize="12" VerticalAlignment="Center" Margin="6,0,12,0" TextTrimming="CharacterEllipsis"/>
    <TextBox x:Name="filterBox" Grid.Column="3" Width="260" Tag="Filtruj wyniki (Ctrl+F)…" Margin="0,0,8,0"/>
    <CheckBox x:Name="chkReveal" Grid.Column="4" Content="Pokaż poufne" Margin="4,0,12,0" Visibility="Collapsed"/>
    <Button x:Name="btnDetail" Grid.Column="5" Style="{StaticResource GhostButton}" ToolTip="Panel szczegółów wiersza" Margin="0,0,4,0"/>
    <Button x:Name="btnCopy" Grid.Column="6" Style="{StaticResource GhostButton}" ToolTip="Kopiuj zaznaczone wiersze lub całą tabelę (format Excel)" Margin="0,0,4,0"/>
    <Button x:Name="btnExport" Grid.Column="7" ToolTip="Eksport widocznych wierszy do CSV"/>
  </Grid>

  <Border Grid.Row="4" Style="{StaticResource Card}" Padding="0">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*" MinWidth="300"/>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition x:Name="detailCol" Width="340" MinWidth="0"/>
      </Grid.ColumnDefinitions>
      <DataGrid x:Name="grid" Style="{StaticResource DarkGrid}" AutoGenerateColumns="False" Margin="1,1,1,6" CanUserReorderColumns="True"/>
      <StackPanel x:Name="emptyState" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False" Margin="20,40,20,20">
        <Border Width="64" Height="64" CornerRadius="32" Background="#1A2029" HorizontalAlignment="Center">
          <TextBlock x:Name="emptyIcon" Style="{StaticResource Glyph}" FontSize="26" Foreground="#4A5568" HorizontalAlignment="Center"/>
        </Border>
        <TextBlock x:Name="emptyText" Text="Brak wyników" FontSize="15" FontWeight="SemiBold" Foreground="#AEB6C4" HorizontalAlignment="Center" Margin="0,14,0,0"/>
        <TextBlock x:Name="emptyHint" Foreground="#5E6779" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" MaxWidth="440" Margin="0,5,0,0"/>
      </StackPanel>
      <GridSplitter x:Name="detailSplit" Grid.Column="1" Width="5" HorizontalAlignment="Stretch" ResizeBehavior="PreviousAndNext"/>
      <Border x:Name="detailPane" Grid.Column="2" BorderBrush="#242B36" BorderThickness="1,0,0,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Grid Margin="14,12,8,6">
            <TextBlock Text="SZCZEGÓŁY WIERSZA" Foreground="#5E6779" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center"/>
            <Button x:Name="btnDetailCopy" Style="{StaticResource GhostButton}" HorizontalAlignment="Right" Padding="6,2" MinHeight="24" ToolTip="Kopiuj szczegóły"/>
          </Grid>
          <TextBox x:Name="detailText" Grid.Row="1" Style="{StaticResource ReadOnlyText}" FontFamily="Segoe UI" FontSize="12.5" Margin="8,0,4,8" Padding="6,0"/>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Grid>
'@

$script:GridModules = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:FilterTimer = $null
$script:FilterPending = $null
$script:GridEvents = @{
    SelectionChanged   = {
        param($s, $e)
        try {
            $m = $null
            if ($script:GridModules.TryGetValue($s, [ref]$m)) { Update-HTDetailText -Module $m }
        }
        catch { Write-Verbose $_ }
    }
    MouseDoubleClick   = {
        param($s, $e)
        try {
            $m = $null
            if (-not $script:GridModules.TryGetValue($s, [ref]$m)) { return }
            $dep = $e.OriginalSource
            while ($dep -and -not ($dep -is [System.Windows.Controls.DataGridRow])) {
                if ($dep -is [System.Windows.Controls.Primitives.DataGridColumnHeader] -or $dep -is [System.Windows.Controls.Primitives.ScrollBar]) { return }
                if ($dep -is [System.Windows.Media.Visual] -or $dep -is [System.Windows.Media.Media3D.Visual3D]) { $dep = [System.Windows.Media.VisualTreeHelper]::GetParent($dep) }
                else { $dep = $null }
            }
            if (-not $dep) { return }
            $drv = $dep.Item
            if (-not ($drv -is [System.Data.DataRowView])) { return }
            if ($m.RowDoubleClick) { Invoke-HTUiAction -Module $m -Action $m.RowDoubleClick -Source $drv }
            else { Show-HTRowDetails -Module $m -Row $drv }
        }
        catch { Write-Log -Message "Nie można wyświetlić szczegółów: $($_.Exception.Message)" -Type 'Error' }
    }
    ContextMenuOpening = {
        param($s, $e)
        try {
            $m = $null
            if (-not $script:GridModules.TryGetValue($s, [ref]$m)) { return }
            Update-HTGridMenu -Module $m
        }
        catch { Write-Verbose $_ }
    }
    MenuClick          = {
        param($s, $e)
        try {
            $entry = $s.Tag
            $m = $entry.Module
            switch ($entry.Kind) {
                'Copy' { Copy-HTResultView -Module $m -SelectedOnly }
                'CopyValue' {
                    $cell = $m.Grid.CurrentCell
                    if ($cell.Column -and $cell.Item -is [System.Data.DataRowView]) {
                        $v = Get-HTExportValue -Module $m -Row $cell.Item -Column ([string]$cell.Column.SortMemberPath)
                        Set-HTClipboard ([string]$v)
                        Show-HTToast 'Skopiowano wartość.' 'ok'
                    }
                }
                'Details' { if ($m.Grid.SelectedItem) { Show-HTRowDetails -Module $m -Row $m.Grid.SelectedItem } }
                default { Invoke-HTUiAction -Module $m -Action $entry.Action -Source @(Get-HTResultSelection -Module $m) }
            }
        }
        catch { Show-HTError 'Operacja nie powiodła się.' $_ }
    }
}

function New-HTModuleView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $root = New-HTUiElement $script:ModuleViewXaml
    $Module.Root = $root
    foreach ($n in 'paramsCard', 'paramsStack', 'statsGrid', 'busyChip', 'busyText', 'countText', 'resultHint', 'filterBox', 'chkReveal',
        'btnDetail', 'btnCopy', 'btnExport', 'grid', 'emptyState', 'emptyIcon', 'emptyText', 'emptyHint', 'detailCol', 'detailSplit',
        'detailPane', 'detailText', 'btnDetailCopy', 'btnCollapse') {
        $Module.View_[$n] = $root.FindName($n)
    }
    $Module.ParamsCard = $Module.View_['paramsCard']
    $Module.ParamsStack = $Module.View_['paramsStack']
    $Module.StatsGrid = $Module.View_['statsGrid']
    $Module.Grid = $Module.View_['grid']
    $Module.FilterBox = $Module.View_['filterBox']

    $root.FindName('hdrIcon').Text = Get-HTGlyph $Module.Icon
    $root.FindName('hdrTitle').Text = $Module.Title
    $root.FindName('hdrCategory').Text = $(if ($Module.WorkspaceTitle) { $Module.WorkspaceTitle + '  •  ' + $Module.Category } else { $Module.Category })
    $desc = $root.FindName('hdrDesc')
    if ($Module.Description) { $desc.Text = $Module.Description } else { $desc.Visibility = 'Collapsed' }

    $v = $Module.View_
    $v.btnDetail.Content = New-HTIconContent -Text '' -Icon 'E8A1'
    $v.btnCopy.Content = New-HTIconContent -Text '' -Icon 'E8C8'
    $v.btnExport.Content = New-HTIconContent -Text 'Eksport' -Icon 'EDE1'
    $v.btnDetailCopy.Content = New-HTIconContent -Text '' -Icon 'E8C8' -IconSize 11
    $v.btnCollapse.Content = New-HTIconContent -Text '' -Icon 'E70E' -IconSize 12
    $v.btnCollapse.Visibility = 'Collapsed'
    Register-HTControlHandler -Control $v.btnCollapse -EventName 'Click' -Module $Module -Action {
        param($m)
        $collapsed = $m.ParamsCard.Visibility -eq 'Visible'
        $m.ParamsCard.Visibility = if ($collapsed) { 'Collapsed' } else { 'Visible' }
        $m.View_.btnCollapse.Content = New-HTIconContent -Text $(if ($collapsed) { 'Parametry' } else { '' }) -Icon $(if ($collapsed) { 'E70D' } else { 'E70E' }) -IconSize 12
    }
    Register-HTControlHandler -Control $v.filterBox -EventName 'TextChanged' -Module $Module -Action { param($m) Request-HTResultFilter -Module $m }
    Register-HTControlHandler -Control $v.btnCopy -EventName 'Click' -Module $Module -Action { param($m) Copy-HTResultView -Module $m }
    Register-HTControlHandler -Control $v.btnExport -EventName 'Click' -Module $Module -Action { param($m) Export-HTResultView -Module $m }
    Register-HTControlHandler -Control $v.btnDetail -EventName 'Click' -Module $Module -Action {
        param($m)
        $script:UI.DetailVisible = -not $script:UI.DetailVisible
        foreach ($other in $script:UI.Modules.Values) { if ($other.Root) { Update-HTDetailPane -Module $other } }
    }
    Register-HTControlHandler -Control $v.btnDetailCopy -EventName 'Click' -Module $Module -Action {
        param($m)
        $t = $m.View_['detailText'].Text
        if ($t) { Set-HTClipboard $t; Show-HTToast 'Skopiowano szczegóły wiersza.' 'ok' }
    }
    Register-HTControlHandler -Control $v.chkReveal -EventName 'Checked' -Module $Module -Action { param($m) Set-HTSecretReveal -Module $m -Reveal $true }
    Register-HTControlHandler -Control $v.chkReveal -EventName 'Unchecked' -Module $Module -Action { param($m) Set-HTSecretReveal -Module $m -Reveal $false }

    $grid = $Module.Grid
    $script:GridModules[$grid] = $Module
    $grid.add_SelectionChanged($script:GridEvents.SelectionChanged)
    $grid.add_MouseDoubleClick($script:GridEvents.MouseDoubleClick)
    $grid.add_ContextMenuOpening($script:GridEvents.ContextMenuOpening)
    $grid.ContextMenu = New-Object System.Windows.Controls.ContextMenu
    Reset-HTResults -Module $Module
    Update-HTDetailPane -Module $Module
}

function Complete-HTModuleView {
    param([Parameter(Mandatory)][hashtable]$Module)
    $v = $Module.View_
    if ($Module.ParamsStack.Children.Count -gt 0) { $v.btnCollapse.Visibility = 'Visible' }
    if ($Module.SecretColumns.Count -gt 0) { $v.chkReveal.Visibility = 'Visible' }
    $v.emptyIcon.Text = Get-HTGlyph $Module.Icon
    if (-not $Module.EmptyHint -and $Module.PrimaryButton) {
        $label = $Module.PrimaryButton.Content
        if ($label -is [System.Windows.Controls.Panel]) { $label = $label.Children[$label.Children.Count - 1].Text }
        $Module.EmptyHint = if ($Module.Panel) { "Zaznacz obiekty na liście po lewej i kliknij «$label» (F5)." } else { "Kliknij «$label» (F5), aby pobrać dane." }
    }
    if ($Module.ResultHint) { $v.resultHint.Text = $Module.ResultHint }
    elseif ($Module.RowActions.Count -gt 0) { $v.resultHint.Text = 'Prawy przycisk myszy na wierszach - akcje' }
    else { $v.resultHint.Text = 'Dwuklik na wierszu - szczegóły' }
    Update-HTResultCount -Module $Module
}

function Add-HTParamRow {
    # Wiersz panelu parametrów z podpisem po lewej (-Title) i dowolną zawartością
    param([Parameter(Mandatory)][hashtable]$Module, [string]$Title = '', [Parameter(Mandatory)]$Content)
    $container = $Content
    if ($Title) {
        $grid = New-Object System.Windows.Controls.Grid
        $c1 = New-Object System.Windows.Controls.ColumnDefinition
        $c1.Width = New-Object System.Windows.GridLength 128
        $c2 = New-Object System.Windows.Controls.ColumnDefinition
        [void]$grid.ColumnDefinitions.Add($c1)
        [void]$grid.ColumnDefinitions.Add($c2)
        $caption = New-Object System.Windows.Controls.TextBlock
        $caption.Text = $Title
        $caption.Foreground = Get-HTBrush '#8791A5'
        $caption.FontWeight = 'SemiBold'
        $caption.FontSize = 12
        $caption.Margin = '0,8,12,0'
        $caption.VerticalAlignment = 'Top'
        $caption.TextWrapping = 'Wrap'
        [void]$grid.Children.Add($caption)
        [System.Windows.Controls.Grid]::SetColumn($Content, 1)
        [void]$grid.Children.Add($Content)
        $container = $grid
    }
    $stack = $Module.ParamsStack
    if ($stack.Children.Count -gt 0) { $container.Margin = '0,4,0,0' }
    [void]$stack.Children.Add($container)
    $Module.ParamsCard.Visibility = 'Visible'
    return $Content
}

function Add-HTToolbarRow {
    param([Parameter(Mandatory)][hashtable]$Module, [string]$Title = '')
    $wrap = New-Object System.Windows.Controls.WrapPanel
    $wrap.Orientation = 'Horizontal'
    return (Add-HTParamRow -Module $Module -Title $Title -Content $wrap)
}

function Add-HTSeparator {
    param([Parameter(Mandatory)][hashtable]$Module)
    $b = New-Object System.Windows.Controls.Border
    $b.Height = 1
    $b.Background = Get-HTBrush '#242B36'
    $b.Margin = '0,8,0,6'
    [void]$Module.ParamsStack.Children.Add($b)
}

function Add-HTLabel {
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)][AllowEmptyString()][string]$Text, [switch]$Hint, [switch]$Bold, [double]$MaxWidth = 0)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.VerticalAlignment = 'Center'
    $t.Margin = '0,0,8,6'
    $t.TextWrapping = 'Wrap'
    if ($MaxWidth -gt 0) { $t.MaxWidth = $MaxWidth }
    if ($Hint) { $t.Foreground = Get-HTBrush '#7B8496'; $t.FontSize = 12 }
    if ($Bold) { $t.FontWeight = 'SemiBold' }
    [void]$Parent.Children.Add($t)
    return $t
}

function Add-HTTextBox {
    param([Parameter(Mandatory)]$Parent, [double]$Width = 200, [string]$Text = '', [string]$Placeholder = '', [switch]$Multiline, [double]$Height = 0)
    $tb = New-Object System.Windows.Controls.TextBox
    if ($Multiline) {
        $tb.Style = Get-HTThemeResource 'MultiText'
        $tb.FontFamily = 'Segoe UI'
        $tb.FontSize = 13
        $tb.TextWrapping = 'Wrap'
        $tb.Height = if ($Height -gt 0) { $Height } else { 90 }
    }
    $tb.Width = $Width
    $tb.Text = $Text
    if ($Placeholder) { $tb.Tag = $Placeholder }
    $tb.Margin = '0,0,8,6'
    [void]$Parent.Children.Add($tb)
    return $tb
}

function Add-HTComboBox {
    param([Parameter(Mandatory)]$Parent, [string[]]$Items = @(), [double]$Width = 180, [int]$Selected = 0, [switch]$Editable)
    $cb = New-Object System.Windows.Controls.ComboBox
    $cb.Width = $Width
    $cb.Margin = '0,0,8,6'
    if ($Editable) { $cb.IsEditable = $true }
    foreach ($i in $Items) { [void]$cb.Items.Add($i) }
    if ($cb.Items.Count -gt 0) { $cb.SelectedIndex = [Math]::Min([Math]::Max(0, $Selected), $cb.Items.Count - 1) }
    [void]$Parent.Children.Add($cb)
    return $cb
}

function Get-HTComboText($ComboBox) {
    if ($ComboBox.IsEditable) { return ([string]$ComboBox.Text).Trim() }
    return [string]$ComboBox.SelectedItem
}

$script:NumericSpecs = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:NumericEvents = @{
    PreviewTextInput = { param($s, $e) if ($e.Text -notmatch '^\d+$') { $e.Handled = $true } }
    LostFocus        = { param($s, $e) try { $s.Text = [string](Get-HTNum $s) } catch { Write-Verbose $_ } }
}

function Add-HTNumeric {
    param([Parameter(Mandatory)]$Parent, [int]$Value = 0, [int]$Minimum = 0, [int]$Maximum = 100000, [double]$Width = 80)
    $tb = New-Object System.Windows.Controls.TextBox
    $tb.Width = $Width
    $tb.Margin = '0,0,8,6'
    $tb.Text = [string]$Value
    $tb.HorizontalContentAlignment = 'Right'
    $script:NumericSpecs[$tb] = @{ Min = $Minimum; Max = $Maximum; Default = $Value }
    $tb.add_PreviewTextInput($script:NumericEvents.PreviewTextInput)
    $tb.add_LostFocus($script:NumericEvents.LostFocus)
    [void]$Parent.Children.Add($tb)
    return $tb
}

function Get-HTNum {
    param([Parameter(Mandatory)]$Control)
    $spec = $null
    if (-not $script:NumericSpecs.TryGetValue($Control, [ref]$spec)) { $spec = @{ Min = 0; Max = [int]::MaxValue; Default = 0 } }
    $v = 0
    if (-not [int]::TryParse(([string]$Control.Text).Trim(), [ref]$v)) { $v = $spec.Default }
    return [Math]::Min($spec.Max, [Math]::Max($spec.Min, $v))
}

function Add-HTCheckBox {
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)][string]$Text, [bool]$Checked = $false, [string]$ToolTip = '')
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = $Text
    $cb.IsChecked = $Checked
    $cb.Margin = '2,0,16,6'
    if ($ToolTip) { $cb.ToolTip = $ToolTip }
    [void]$Parent.Children.Add($cb)
    return $cb
}

function Test-HTChecked($CheckBox) { return ($CheckBox.IsChecked -eq $true) }

$script:SegmentCounter = 0
function Add-HTSegmented {
    # Przełącznik segmentowy; indeks wyboru: Get-HTSegmentIndex
    param([AllowNull()]$Parent, [Parameter(Mandatory)][string[]]$Items, [int]$Selected = 0, [hashtable]$Module, [scriptblock]$OnChange)
    $script:SegmentCounter++
    $group = 'seg' + $script:SegmentCounter
    $container = New-Object System.Windows.Controls.Border
    $container.Style = Get-HTThemeResource 'SegmentHost'
    $container.Margin = '0,0,8,6'
    $container.HorizontalAlignment = 'Left'
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $container.Child = $sp
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Style = Get-HTThemeResource 'SegmentRadio'
        $rb.GroupName = $group
        $rb.Content = $Items[$i]
        $rb.IsChecked = ($i -eq $Selected)
        if ($OnChange) { Register-HTControlHandler -Control $rb -EventName 'Checked' -Module $Module -Action $OnChange }
        [void]$sp.Children.Add($rb)
    }
    if ($Parent) { [void]$Parent.Children.Add($container) }
    return $container
}

function Get-HTSegmentIndex($Segmented) {
    $i = 0
    foreach ($rb in $Segmented.Child.Children) {
        if ($rb.IsChecked -eq $true) { return $i }
        $i++
    }
    return -1
}

function Add-HTButton {
    # Przycisk akcji modułu (wyłączany na czas operacji). Pierwszy -Primary jest domyślną akcją (F5).
    param(
        [Parameter(Mandatory)]$Parent,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][scriptblock]$OnClick,
        [string]$Icon = '',
        [string]$ToolTip = '',
        [switch]$Primary,
        [switch]$Danger
    )
    $b = New-HTButton -Text $Text -Icon $Icon -Primary:$Primary -Danger:$Danger -ToolTip $ToolTip
    $b.Margin = '0,0,8,6'
    Register-HTControlHandler -Control $b -EventName 'Click' -Module $Module -Action $OnClick
    [void]$Module.Buttons.Add($b)
    if ($Primary -and -not $Module.PrimaryButton) { $Module.PrimaryButton = $b }
    [void]$Parent.Children.Add($b)
    return $b
}

function Add-HTRowAction {
    # Akcja w menu kontekstowym tabeli wyników: { param($m, $rows) } - $rows to zaznaczone obiekty wyników
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Text, [Parameter(Mandatory)][scriptblock]$Action, [string]$Icon = 'E76C', [switch]$Danger)
    [void]$Module.RowActions.Add(@{ Text = $Text; Action = $Action; Icon = $Icon; Danger = [bool]$Danger })
}

function Update-HTGridMenu {
    param([hashtable]$Module)
    $menu = $Module.Grid.ContextMenu
    $menu.Items.Clear()
    $hasRows = $Module.Grid.SelectedItems.Count -gt 0
    foreach ($a in $Module.RowActions) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $a.Text
        $mi.Icon = New-HTGlyphBlock -Code $a.Icon -Size 13 -Color $(if ($a.Danger) { '#FF7A86' } else { '' })
        $mi.IsEnabled = $hasRows
        $mi.Tag = @{ Module = $Module; Kind = 'Action'; Action = $a.Action }
        $mi.add_Click($script:GridEvents.MenuClick)
        [void]$menu.Items.Add($mi)
    }
    if ($Module.RowActions.Count -gt 0) {
        $sep = New-Object System.Windows.Controls.Separator
        $sep.Style = Get-HTThemeResource 'MenuSeparator'
        [void]$menu.Items.Add($sep)
    }
    foreach ($item in @(@('Details', 'Szczegóły wiersza', 'E8A1'), @('CopyValue', 'Kopiuj wartość komórki', 'E8C8'), @('Copy', 'Kopiuj zaznaczone wiersze', 'E8C8'))) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $item[1]
        $mi.Icon = New-HTGlyphBlock -Code $item[2] -Size 13
        $mi.IsEnabled = $hasRows
        $mi.Tag = @{ Module = $Module; Kind = $item[0] }
        $mi.add_Click($script:GridEvents.MenuClick)
        [void]$menu.Items.Add($mi)
    }
}

function Add-HTStatTile {
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][string]$Label, [string]$Icon = '', [string]$Value = '–')
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Padding="14,10" Margin="0,0,10,0">
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
    <Border Width="34" Height="34" CornerRadius="8" Background="#1B2333" Margin="0,0,12,0" VerticalAlignment="Center">
      <TextBlock Name="icon" Style="{StaticResource Glyph}" FontSize="15" Foreground="#8CB0FF" HorizontalAlignment="Center"/>
    </Border>
    <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <TextBlock Name="value" FontSize="20" FontWeight="SemiBold" Foreground="White"/>
      <TextBlock Name="label" FontSize="11.5" Foreground="#8791A5" TextTrimming="CharacterEllipsis"/>
    </StackPanel>
  </Grid>
</Border>
"@
    $tile = New-HTUiElement $xaml
    $tile.Style = Get-HTThemeResource 'Card'
    $tile.Padding = '14,10'
    $tile.FindName('icon').Text = Get-HTGlyph $(if ($Icon) { $Icon } else { 'E9D2' })
    $tile.FindName('value').Text = $Value
    $tile.FindName('label').Text = $Label
    $Module.Stats[$Key] = $tile
    [void]$Module.StatsGrid.Children.Add($tile)
    $Module.StatsGrid.Columns = $Module.StatsGrid.Children.Count
    $Module.StatsGrid.Visibility = 'Visible'
    return $tile
}

function Set-HTStatTile {
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Key, [string]$Value = '–', [ValidateSet('', 'ok', 'warn', 'crit', 'info', 'off')][string]$Tone = '', [string]$Label = '')
    $tile = $Module.Stats[$Key]
    if (-not $tile) { return }
    $v = $tile.FindName('value')
    $v.Text = $Value
    $v.Foreground = Get-HTBrush $(switch ($Tone) { 'ok' { '#5EE3AE' } 'warn' { '#FFC46B' } 'crit' { '#FF7A86' } 'info' { '#8CC0FF' } 'off' { '#5E6779' } default { '#FFFFFF' } })
    if ($Label) { $tile.FindName('label').Text = $Label }
}

function Reset-HTResults {
    # Czyści tabelę wyników (nowe wyniki - nowe kolumny)
    param([Parameter(Mandatory)][hashtable]$Module)
    $table = New-Object System.Data.DataTable 'Wyniki'
    foreach ($c in '__search', '__flag') { [void]$table.Columns.Add($c, [string]) }
    [void]$table.Columns.Add('__obj', [object])
    $view = [System.Data.DataView]::new($table)
    $Module.Table = $table
    $Module.View = $view
    $Module.ColumnIndex = @{}
    $Module.Objects.Clear()
    $g = $Module.Grid
    if ($g) {
        $g.ItemsSource = $null
        $g.Columns.Clear()
        $g.ItemsSource = $view
    }
    Update-HTResultFilter -Module $Module
}

function Add-HTGridColumn {
    param([hashtable]$Module, [string]$Name)
    $g = $Module.Grid
    if (-not $g -or $Module.ColumnIndex.ContainsKey($Name)) { return }
    $Module.ColumnIndex[$Name] = $true
    if ($Name.StartsWith('__') -or $Module.HiddenColumns -contains $Name) { return }
    $col = New-Object System.Windows.Controls.DataGridTextColumn
    $col.Binding = New-Object System.Windows.Data.Binding ('[' + $Name + ']')
    $style = New-Object System.Windows.Style ([System.Windows.Controls.TextBlock])
    $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.Controls.TextBlock]::TextTrimmingProperty, [System.Windows.TextTrimming]::CharacterEllipsis)))
    $style.Setters.Add((New-Object System.Windows.Setter([System.Windows.FrameworkElement]::MaxHeightProperty, [double]18)))
    $col.ElementStyle = $style
    if ($Module.GoodWhenNo -contains $Name) { $col.CellStyle = Get-HTThemeResource 'BoolCellInv' }
    elseif ($Module.ColorBools) { $col.CellStyle = Get-HTThemeResource 'BoolCell' }
    $col.Header = $Name
    $col.SortMemberPath = $Name
    $col.IsReadOnly = $true
    $col.MaxWidth = 520
    $col.MinWidth = 54
    $g.Columns.Add($col)
}

function Add-HTResultRows {
    <#
        Dodaje obiekty jako wiersze tabeli modułu; nowe właściwości tworzą nowe kolumny.
        Właściwość __flag (crit/warn/muted) koloruje wiersz. Oryginalny obiekt zostaje zapamiętany
        (Get-HTResultSelection zwraca go dla zaznaczonych wierszy).
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [AllowEmptyCollection()][object[]]$Objects)
    $table = $Module.Table
    if ($null -eq $table) { return }
    $table.BeginLoadData()
    try {
        foreach ($obj in $Objects) {
            if ($null -eq $obj) { continue }
            $values = New-Object System.Collections.Specialized.OrderedDictionary
            $base = if ($obj -is [System.Management.Automation.PSObject]) { $obj.PSObject.BaseObject } else { $obj }
            # Właściwości z prefiksem __ (poza __flag) są pomocnicze - zostają tylko w obiekcie wiersza (__obj)
            if ($base -is [string] -or $base -is [System.ValueType]) { $values['Wynik'] = ConvertTo-HTCellValue $base }
            elseif ($base -is [System.Collections.IDictionary]) {
                foreach ($k in $base.Keys) {
                    $name = [string]$k
                    if ($name -eq '__flag') { $values[$name] = [string]$base[$k] }
                    elseif (-not $name.StartsWith('__')) { $values[$name] = ConvertTo-HTCellValue $base[$k] }
                }
            }
            else {
                foreach ($p in $obj.PSObject.Properties) {
                    if ($p.Name -eq '__flag') { $values[$p.Name] = [string]$p.Value }
                    elseif (-not $p.Name.StartsWith('__')) { $values[$p.Name] = ConvertTo-HTCellValue $p.Value }
                }
            }
            foreach ($name in @($values.Keys)) {
                if (-not $table.Columns.Contains($name)) { [void]$table.Columns.Add($name, [object]) }
                if ($Module.SecretColumns -contains $name -and -not $table.Columns.Contains("__secret_$name")) { [void]$table.Columns.Add("__secret_$name", [object]) }
                Add-HTGridColumn -Module $Module -Name $name
            }
            $row = $table.NewRow()
            $search = New-Object System.Text.StringBuilder
            foreach ($name in $values.Keys) {
                $v = $values[$name]
                if ($Module.SecretColumns -contains $name) {
                    $row["__secret_$name"] = $v
                    if (-not $Module.RevealSecrets -and $v -isnot [System.DBNull] -and [string]$v -ne '') { $v = '••••••••••' }
                    $row[$name] = $v
                    continue
                }
                $row[$name] = $v
                if ($v -isnot [System.DBNull] -and -not $name.StartsWith('__')) { [void]$search.Append([string]$v).Append(' ') }
            }
            $row['__search'] = $search.ToString().ToLowerInvariant()
            $row['__obj'] = $obj
            if (-not $values.Contains('__flag')) {
                $status = [string]$values['Status']
                if ($status.StartsWith('Błąd')) { $row['__flag'] = 'crit' }
                elseif ($status.StartsWith('Pominięto') -or $status.StartsWith('Test')) { $row['__flag'] = 'muted' }
            }
            $table.Rows.Add($row)
        }
    }
    finally { $table.EndLoadData() }
    Update-HTResultCount -Module $Module
    Update-HTUi
}

function Get-HTResultSelection {
    # Oryginalne obiekty zaznaczonych wierszy tabeli wyników
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$AllVisible)
    $rows = if ($AllVisible) { @($Module.View | ForEach-Object { $_ }) } else { @($Module.Grid.SelectedItems) }
    foreach ($drv in $rows) {
        if ($drv -is [System.Data.DataRowView]) {
            $o = $drv.Row['__obj']
            if ($o -isnot [System.DBNull]) { $o }
        }
    }
}

function Set-HTSecretReveal {
    param([hashtable]$Module, [bool]$Reveal)
    $Module.RevealSecrets = $Reveal
    foreach ($row in $Module.Table.Rows) {
        foreach ($name in $Module.SecretColumns) {
            if (-not $Module.Table.Columns.Contains($name)) { continue }
            $real = $row["__secret_$name"]
            $row[$name] = if ($Reveal -or $real -is [System.DBNull] -or [string]$real -eq '') { $real } else { '••••••••••' }
        }
    }
}

function Request-HTResultFilter {
    # Filtr z opóźnieniem (wpisywanie nie przelicza tabeli przy każdym znaku)
    param([hashtable]$Module)
    if (-not $script:FilterTimer) {
        $script:FilterTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:FilterTimer.Interval = [TimeSpan]::FromMilliseconds(220)
        $script:FilterTimer.add_Tick({
                param($s, $e)
                $s.Stop()
                $m = $script:FilterPending
                $script:FilterPending = $null
                if ($m) { Update-HTResultFilter -Module $m }
            })
    }
    if ($script:FilterPending -and -not [object]::ReferenceEquals($script:FilterPending, $Module)) { Update-HTResultFilter -Module $script:FilterPending }
    $script:FilterPending = $Module
    $script:FilterTimer.Stop()
    $script:FilterTimer.Start()
}

function Update-HTResultFilter {
    param([hashtable]$Module)
    if ($null -eq $Module.View) { return }
    $text = if ($Module.FilterBox) { $Module.FilterBox.Text } else { '' }
    Set-HTViewFilter -View $Module.View -Text $text
    Update-HTResultCount -Module $Module
}

function Update-HTResultCount {
    param([hashtable]$Module)
    if ($null -eq $Module.View -or -not $Module.View_) { return }
    $total = $Module.Table.Rows.Count
    $visible = $Module.View.Count
    $g = $Module.Grid
    if ($g) { $g.HeadersVisibility = if ($g.Columns.Count -gt 0) { 'Column' } else { 'None' } }
    $count = $Module.View_['countText']
    if ($count) { $count.Text = if ($visible -eq $total) { [string]$total } else { "$visible z $total" } }
    $empty = $Module.View_['emptyState']
    if ($empty) {
        if ($visible -gt 0) { $empty.Visibility = 'Collapsed' }
        else {
            $empty.Visibility = 'Visible'
            if ($total -gt 0) {
                $Module.View_['emptyText'].Text = 'Nic nie pasuje do filtra'
                $Module.View_['emptyHint'].Text = 'Zmień lub wyczyść filtr. Słowo poprzedzone minusem wyklucza wiersze.'
            }
            else {
                $Module.View_['emptyText'].Text = $(if ($Module.EmptyText) { $Module.EmptyText } else { 'Brak wyników' })
                $Module.View_['emptyHint'].Text = [string]$Module.EmptyHint
            }
        }
    }
}

function Update-HTDetailPane {
    param([hashtable]$Module)
    $v = $Module.View_
    if (-not $v -or -not $v['detailPane']) { return }
    if ($script:UI.DetailVisible) {
        $v.detailPane.Visibility = 'Visible'
        $v.detailSplit.Visibility = 'Visible'
        if ($v.detailCol.Width.Value -lt 120) { $v.detailCol.Width = New-Object System.Windows.GridLength 340 }
    }
    else {
        $v.detailPane.Visibility = 'Collapsed'
        $v.detailSplit.Visibility = 'Collapsed'
        $v.detailCol.Width = New-Object System.Windows.GridLength 0
    }
}

function Get-HTExportValue {
    # Wartość komórki do kopiowania i eksportu (wartości poufne - prawdziwe tylko po «Pokaż poufne»)
    param([hashtable]$Module, $Row, [string]$Column)
    if ($Module.SecretColumns -contains $Column -and $Module.RevealSecrets) { return Get-HTObjectValue $Row "__secret_$Column" }
    return Get-HTObjectValue $Row $Column
}

function Get-HTVisibleColumnNames {
    param([hashtable]$Module)
    return @($Module.Grid.Columns | Sort-Object DisplayIndex | ForEach-Object { [string]$_.SortMemberPath })
}

function Format-HTRowDetails {
    param([hashtable]$Module, $Row)
    $sb = New-Object System.Text.StringBuilder
    foreach ($col in $Module.Table.Columns) {
        $name = $col.ColumnName
        if ($name.StartsWith('__')) { continue }
        $v = Get-HTExportValue -Module $Module -Row $Row -Column $name
        if ([string]$v -eq '') { continue }
        $text = [string]$v
        if ($text -match "[\r\n]") { [void]$sb.AppendLine("${name}:").AppendLine($text.Trim()).AppendLine() }
        else { [void]$sb.AppendLine(('{0}:  {1}' -f $name, $text)) }
    }
    return $sb.ToString()
}

function Update-HTDetailText {
    param([hashtable]$Module)
    $box = $Module.View_['detailText']
    if (-not $box) { return }
    $item = $Module.Grid.SelectedItem
    $box.Text = if ($item -is [System.Data.DataRowView]) { Format-HTRowDetails -Module $Module -Row $item } else { '' }
}

function Show-HTRowDetails {
    param([hashtable]$Module, $Row)
    if (-not ($Row -is [System.Data.DataRowView])) { return }
    $title = 'Szczegóły'
    foreach ($c in 'Obiekt', 'Nazwa', 'Użytkownik', 'Skrzynka', 'Urządzenie', 'Name') {
        $v = Get-HTObjectValue $Row $c
        if ($v) { $title = "Szczegóły - $v"; break }
    }
    Show-HTTextDialog -Title $title -Subtitle $Module.Title -Text (Format-HTRowDetails -Module $Module -Row $Row)
}

function Copy-HTResultView {
    param([hashtable]$Module, [switch]$SelectedOnly)
    $columns = Get-HTVisibleColumnNames -Module $Module
    if ($columns.Count -eq 0) { return }
    $rows = if ($Module.Grid.SelectedItems.Count -gt 0) { @($Module.Grid.SelectedItems) } elseif ($SelectedOnly) { @() } else { @($Module.View | ForEach-Object { $_ }) }
    if ($rows.Count -eq 0) { return }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add($columns -join "`t")
    foreach ($r in $rows) { $lines.Add((($columns | ForEach-Object { ([string](Get-HTExportValue -Module $Module -Row $r -Column $_)) -replace "[`t`r`n]+", ' ' }) -join "`t")) }
    Set-HTClipboard -Text ($lines -join "`r`n") -Secret:($Module.RevealSecrets -and $Module.SecretColumns.Count -gt 0)
    Show-HTToast "Skopiowano wierszy: $($rows.Count)." 'ok'
}

function Export-HTResultView {
    param([hashtable]$Module)
    $columns = Get-HTVisibleColumnNames -Module $Module
    $rows = @($Module.View | ForEach-Object { $_ })
    if ($columns.Count -eq 0 -or $rows.Count -eq 0) { Show-HTMessage -Text 'Brak wyników do eksportu.' -Title 'Eksport'; return }
    $data = foreach ($r in $rows) {
        $o = [ordered]@{}
        foreach ($c in $columns) { $v = Get-HTExportValue -Module $Module -Row $r -Column $c; $o[$c] = if ($null -eq $v) { '' } else { [string]$v } }
        [PSCustomObject]$o
    }
    $name = ($Module.Title -replace '[^\w\-]+', '_')
    Save-ContentToFile -Data @($data) -Format 'csv' -Title 'Eksport wyników' -DefaultName $name | Out-Null
}

function Invoke-HTTargetAction {
    <#
        Wykonuje operację dla każdego obiektu docelowego i dopisuje wiersze wyników (Obiekt, Status, Szczegóły).
        -Action { param($t) } zwraca tekst szczegółów, hashtablę z dodatkowymi kolumnami albo obiekt.
        -Confirm: tekst pytania (lista obiektów jest dołączana automatycznie).
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [object[]]$Targets,
        [scriptblock]$Label,
        [string]$Confirm = '',
        [switch]$Danger,
        [string]$TypeToConfirm = '',
        [switch]$KeepResults,
        [string]$Service = ''
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    if (-not $Targets) { $Targets = @(Get-HTTargets -Module $Module) }
    if ($Targets.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($t) Get-HTTargetLabel $t } }
    $labels = @($Targets | ForEach-Object { [string](& $Label $_) })
    if ($Confirm -and -not (Show-HTConfirm -Message $Confirm -Title $Name -Items $labels -Danger:$Danger -Warning:(-not $Danger) -TypeToConfirm $TypeToConfirm -ConfirmText $(if ($Danger) { 'Wykonaj' } else { 'Wykonaj' }))) { return }
    if (-not $KeepResults) { Reset-HTResults -Module $Module }
    Set-HTBusy -Busy $true -Text "$Name…"
    $ok = 0
    $failed = 0
    try {
        for ($i = 0; $i -lt $Targets.Count; $i++) {
            $t = $Targets[$i]
            Set-HTProgress -Value ($i + 1) -Maximum $Targets.Count -Text "$Name [$($i + 1)/$($Targets.Count)] $($labels[$i])"
            $row = [ordered]@{ Obiekt = $labels[$i]; Status = 'OK' }
            try {
                $result = & $Action $t
                if ($result -is [System.Collections.IDictionary]) { foreach ($k in $result.Keys) { $row[$k] = $result[$k] } }
                elseif ($result -is [string] -or $result -is [System.ValueType]) { $row['Szczegóły'] = [string]$result }
                elseif ($null -ne $result) { foreach ($p in $result.PSObject.Properties) { $row[$p.Name] = $p.Value } }
                if ($row.Status -eq 'OK') { $ok++ } elseif ([string]$row.Status -like 'Błąd*') { $failed++ }
            }
            catch {
                $row.Status = 'Błąd'
                $row['Szczegóły'] = $_.Exception.Message
                $failed++
            }
            $level = if ($row.Status -eq 'Błąd') { 'Warn' } else { 'Info' }
            Write-Log -Message "$Name - $($labels[$i]): $($row.Status) $(if ($row.Contains('Szczegóły') -and $Module.SecretColumns -notcontains 'Szczegóły') { $row['Szczegóły'] })" -Type $level
            $row['__target'] = $t
            Add-HTResultRows -Module $Module -Objects @([PSCustomObject]$row)
        }
    }
    finally {
        Set-HTBusy -Busy $false -Text "$Name - zakończono: $ok OK, błędy: $failed"
    }
    $tone = if ($failed -gt 0) { 'warn' } else { 'ok' }
    Show-HTToast "$Name - wykonano: $ok, błędy: $failed." $tone
}

function Get-HTTargetLabel {
    # Czytelna nazwa obiektu (do wyników i potwierdzeń)
    param($Target)
    foreach ($p in 'UserPrincipalName', 'PrimarySmtpAddress', 'DeviceName', 'SamAccountName', 'DisplayName', 'Name', 'Title', 'ServerRelativeUrl') {
        $v = Get-HTObjectValue $Target $p
        if ($v) { return [string]$v }
    }
    return [string]$Target
}
#endregion

#region Zapytania: wyniki dla zaznaczonych obiektów i dane ogólne
function Invoke-HTQuery {
    <#
        Pobiera dane i wpisuje je do tabeli wyników modułu: -ScriptBlock zwraca obiekty (wiersze)
        albo sam dopisuje je przez Add-HTResultRows (np. z postępem). Zwraca liczbę wierszy.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [string]$Service = '',
        [switch]$KeepResults
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    if (-not $KeepResults) { Reset-HTResults -Module $Module }
    Set-HTBusy -Busy $true -Text "$Name…"
    $count = 0
    try {
        $data = @(& $ScriptBlock | Where-Object { $null -ne $_ })
        if ($data.Count -gt 0) { Add-HTResultRows -Module $Module -Objects $data }
        $count = $Module.Table.Rows.Count
        Write-Log -Message "$Name - wyników: $count" -Type 'Info'
        Set-HTBusy -Busy $false -Text "$Name - wyników: $count"
    }
    catch {
        Write-Log -Message "$Name - błąd: $($_.Exception.Message)" -Type 'Error'
        Set-HTBusy -Busy $false -Text "Błąd: $Name"
        Show-HTError -Text $Name -ErrorObject $_
    }
}

function Invoke-HTTargetQuery {
    <#
        Dla każdego obiektu docelowego wykonuje -Action { param($t) } zwracające wiersze wyników.
        Przy kilku obiektach wiersze dostają kolumnę «Obiekt»; każdy wiersz zna swój obiekt (__target).
        Błąd dla obiektu daje wiersz ze statusem «Błąd» - pozostałe obiekty są przetwarzane dalej.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [object[]]$Targets,
        [scriptblock]$Label,
        [string]$Service = '',
        [switch]$Single,
        [switch]$AlwaysShowObject
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    if (-not $Targets) { $Targets = @(Get-HTTargets -Module $Module -Single:$Single) }
    if ($Targets.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($t) Get-HTTargetLabel $t } }
    $showObject = $AlwaysShowObject -or $Targets.Count -gt 1
    Reset-HTResults -Module $Module
    Set-HTBusy -Busy $true -Text "$Name…"
    $failed = 0
    try {
        for ($i = 0; $i -lt $Targets.Count; $i++) {
            $t = $Targets[$i]
            $caption = [string](& $Label $t)
            if ($Targets.Count -gt 1) { Set-HTProgress -Value ($i + 1) -Maximum $Targets.Count -Text "$Name [$($i + 1)/$($Targets.Count)] $caption" }
            $rows = New-Object System.Collections.Generic.List[object]
            try {
                foreach ($r in @(& $Action $t)) {
                    if ($null -eq $r) { continue }
                    $o = [ordered]@{}
                    if ($showObject) { $o['Obiekt'] = $caption }
                    $base = if ($r -is [System.Management.Automation.PSObject]) { $r.PSObject.BaseObject } else { $r }
                    if ($base -is [System.Collections.IDictionary]) { foreach ($k in $base.Keys) { $o[[string]$k] = $base[$k] } }
                    elseif ($base -is [string] -or $base -is [System.ValueType]) { $o['Wynik'] = $base }
                    else { foreach ($p in $r.PSObject.Properties) { $o[$p.Name] = $p.Value } }
                    $o['__target'] = $t
                    $rows.Add([PSCustomObject]$o)
                }
            }
            catch {
                $failed++
                Write-Log -Message "$Name - $($caption): $($_.Exception.Message)" -Type 'Warn'
                $rows.Add([PSCustomObject][ordered]@{ Obiekt = $caption; Status = 'Błąd'; Szczegóły = $_.Exception.Message; __target = $t; __flag = 'crit' })
            }
            if ($rows.Count -gt 0) { Add-HTResultRows -Module $Module -Objects $rows.ToArray() }
        }
    }
    finally {
        $count = $Module.Table.Rows.Count
        Set-HTBusy -Busy $false -Text "$Name - wyników: $count$(if ($failed) { ", błędy: $failed" })"
    }
    Write-Log -Message "$Name ($($Targets.Count) obiekt.) - wyników: $($Module.Table.Rows.Count)$(if ($failed) { ", błędy: $failed" })" -Type $(if ($failed) { 'Warn' } else { 'Info' })
}

function Get-HTRowTarget {
    # Obiekt docelowy, z którego pochodzi wiersz wyników (Invoke-HTTargetQuery / Invoke-HTTargetAction)
    param($Row)
    return Get-HTObjectValue $Row '__target'
}

function Invoke-HTRowAction {
    <#
        Operacja dla zaznaczonych wierszy wyników (menu kontekstowe): -Action { param($row) } zwraca opis wyniku.
        Po zakończeniu opcjonalnie odświeża widok (-Refresh { param($m) }).
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Module,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][scriptblock]$Action,
        [scriptblock]$Label,
        [string]$Confirm = '',
        [switch]$Danger,
        [string]$TypeToConfirm = '',
        [scriptblock]$Refresh,
        [string]$Service = ''
    )
    $service = if ($PSBoundParameters.ContainsKey('Service')) { $Service } else { $Module.Service }
    if ($service -and -not (Assert-HTConnection -Service $service)) { return }
    $Rows = @($Rows | Where-Object { $null -ne $_ })
    if ($Rows.Count -eq 0) { return }
    if (-not $Label) { $Label = { param($r) foreach ($n in 'Nazwa', 'Obiekt', 'Adres', 'UPN', 'Użytkownik', 'Temat', 'Grupa', 'Rola', 'Wartość') { $v = Get-HTObjectValue $r $n; if ($v) { return [string]$v } }; return [string]$r } }
    $labels = @($Rows | ForEach-Object { [string](& $Label $_) })
    if ($Confirm -and -not (Show-HTConfirm -Message $Confirm -Title $Name -Items $labels -Danger:$Danger -Warning:(-not $Danger) -TypeToConfirm $TypeToConfirm)) { return }
    Set-HTBusy -Busy $true -Text "$Name…"
    $ok = 0
    $errors = New-Object System.Collections.Generic.List[string]
    try {
        for ($i = 0; $i -lt $Rows.Count; $i++) {
            if ($Rows.Count -gt 1) { Set-HTProgress -Value ($i + 1) -Maximum $Rows.Count -Text "$Name [$($i + 1)/$($Rows.Count)] $($labels[$i])" }
            try {
                $detail = & $Action $Rows[$i]
                $ok++
                Write-Log -Message "$Name - $($labels[$i]): OK $(if ($detail -is [string]) { $detail })" -Type 'Info'
            }
            catch {
                $errors.Add("$($labels[$i]): $($_.Exception.Message)")
                Write-Log -Message "$Name - $($labels[$i]): $($_.Exception.Message)" -Type 'Warn'
            }
        }
    }
    finally { Set-HTBusy -Busy $false -Text "$Name - wykonano: $ok, błędy: $($errors.Count)" }
    if ($errors.Count -gt 0) { Show-HTWarning -Title $Name -Text ("Wykonano: $ok, błędy: $($errors.Count)`n`n" + (($errors | Select-Object -First 30) -join "`n")) }
    else { Show-HTToast "$Name - wykonano: $ok." 'ok' }
    if ($Refresh -and $ok -gt 0) { Invoke-HTUiAction -Module $Module -Action $Refresh }
}

function Add-HTPanelLoader {
    <#
        Przycisk «Wczytaj» listy obiektów: -Loader { param($p) } zwraca obiekty listy.
        Lista z -Service wczytuje się sama po połączeniu z usługą (Invoke-HTPanelAutoLoad), o ile jest pusta.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Panel,
        [Parameter(Mandatory)][scriptblock]$Loader,
        [string]$Service = '',
        [string]$Text = 'Wczytaj',
        [string]$Icon = 'E72C',
        [string]$ToolTip = 'Wczytaj (odśwież) listę obiektów'
    )
    $Panel.Service = $Service
    $Panel.Loader = $Loader
    return (Add-HTPanelButton -Panel $Panel -Text $Text -Icon $Icon -Primary -ToolTip $ToolTip -OnClick { param($p) Invoke-HTPanelLoad -Panel $p })
}

function Invoke-HTPanelLoad {
    param([Parameter(Mandatory)][hashtable]$Panel, [switch]$Quiet)
    if (-not $Panel.Loader) { return }
    if ($Panel.Service -and -not (Test-HTConnection -Service $Panel.Service)) {
        if (-not $Quiet) { [void](Assert-HTConnection -Service $Panel.Service) }
        return
    }
    $title = $Panel.pTitle.Text.ToLowerInvariant()
    Set-HTBusy -Busy $true -Text "Wczytywanie: $title…"
    try {
        if ($Panel.IsTree) { $null = & $Panel.Loader $Panel }
        else {
            $items = @(& $Panel.Loader $Panel)
            Set-HTTargetItems -Panel $Panel -Items $items
        }
        $count = if ($Panel.IsTree) { $Panel.pTree.Items.Count } else { $Panel.Table.Rows.Count }
        Update-HTTargetCount $Panel
        Write-Log -Message "Wczytano listę '$title': $count" -Type 'Info'
        Set-HTBusy -Busy $false -Text "Wczytano: $count"
    }
    catch {
        Write-Log -Message "Wczytywanie '$title' - błąd: $($_.Exception.Message)" -Type 'Error'
        Set-HTBusy -Busy $false -Text 'Błąd wczytywania'
        if (-not $Quiet) { Show-HTError -Text "Nie udało się wczytać listy: $title" -ErrorObject $_ }
    }
}

function Invoke-HTPanelAutoLoad {
    # Po połączeniu z usługą: wczytuje pustą listę aktywnej przestrzeni; pozostałe wczytają się przy pierwszym otwarciu
    param([Parameter(Mandatory)][string]$Service)
    $active = $script:UI.Workspaces[[string]$script:UI.ActiveWorkspace]
    $panels = @($script:UI.Panels.Values | Where-Object { $_.Service -eq $Service -and $_.Loader })
    $panels = @($panels | Sort-Object { if ($active -and $_.Key -eq $active.Panel) { 0 } else { 1 } })
    foreach ($p in $panels) {
        $empty = if ($p.IsTree) { $p.pTree.Items.Count -eq 0 } else { $p.Table.Rows.Count -eq 0 }
        if ($empty -and $active -and $p.Key -eq $active.Panel) { $p.AutoTried = $true; Invoke-HTPanelLoad -Panel $p -Quiet }
        elseif ($empty) { $p.AutoTried = $false }
    }
}

function Clear-HTPanelItems {
    # Czyści listy obiektów zależne od usługi (np. po rozłączeniu lub zmianie tenantu)
    param([Parameter(Mandatory)][string]$Service)
    foreach ($p in @($script:UI.Panels.Values | Where-Object { $_.Service -eq $Service })) {
        if ($p.IsTree) { $p.pTree.Items.Clear() } else { Set-HTTargetItems -Panel $p -Items @() }
        $p.AutoTried = $false
        Update-HTTargetCount $p
    }
}

function Select-HTOne {
    # Wybór jednego obiektu z listy (okno z wyszukiwaniem); zwraca obiekt albo $null
    param([Parameter(Mandatory)][string]$Title, [AllowEmptyCollection()][object[]]$Items, [object[]]$Columns, [string]$Prompt = '')
    $selected = Show-HTSelectionDialog -Title $Title -Items $Items -Columns $Columns -Prompt $Prompt
    if (-not $selected) { return $null }
    return @($selected)[0]
}
#endregion
